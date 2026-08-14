# Buffered, single-request event logging to Google Sheets ---------------------
#
# Why this file exists:
#
#   googlesheets4::sheet_append() costs TWO API requests per call -- a
#   spreadsheets.get (READ bucket) to resolve the sheet, then a batchUpdate
#   (WRITE bucket). The Sheets API allows 60 requests/min per *user*, and the
#   "user" is the one service account shared by every tutorial, lab, and
#   dashboard. So each logged event consumed one slot in each of two 60/min
#   buckets, and a class opening a tutorial together blew through both.
#
#   This module buffers rows in a process-level queue and flushes each tab with
#   a single spreadsheets.values.append -- ONE request, no metadata read. All
#   concurrent sessions served by the same R process share the queue, so a
#   flush covers every student on that worker at once.
#
# Cell types are preserved exactly as sheet_append() wrote them (verified
# against googlesheets4:::as_RowData): strings stay strings, numbers stay
# numbers, logicals stay booleans, NA becomes an empty cell. valueInputOption
# is RAW, NOT USER_ENTERED -- USER_ENTERED would coerce "2026-08-13" into a
# real date cell and change what the dashboards read back.

.uucop_events <- new.env(parent = emptyenv())
.uucop_events$queues     <- list()   # key = "<sheet_id>\r<tab>" -> list of rows
.uucop_events$timer_live <- FALSE
.uucop_events$flushing   <- FALSE
.uucop_events$dropped    <- 0L

#' Queue a row for buffered append to Google Sheets
#'
#' Drop-in replacement for [googlesheets4::sheet_append()] with the same
#' signature. Instead of writing immediately (2 API requests), the row is added
#' to a process-level queue that is flushed on a timer and at session end, one
#' request per sheet tab.
#'
#' @param ss Google Sheet ID.
#' @param data A data frame of rows to append. Column *order* must match the
#'   tab's columns; names are ignored, exactly as `sheet_append()` behaves.
#' @param sheet Name of the tab to append to.
#'
#' @return Invisibly, the number of rows queued.
#' @export
uucop_sheet_append <- function(ss, data, sheet) {
  if (is.null(ss) || !nzchar(ss) || is.null(data) || !nrow(data)) {
    return(invisible(0L))
  }

  key   <- paste(ss, sheet, sep = "\r")
  rows  <- .uucop_row_list(data)
  queue <- c(.uucop_events$queues[[key]], rows)

  cap <- getOption("uucop.buffer_max", 2000L)
  if (length(queue) > cap) {
    over <- length(queue) - cap
    queue <- utils::tail(queue, cap)
    .uucop_events$dropped <- .uucop_events$dropped + over
    message("uucop: event buffer full for '", sheet, "', dropped ", over,
            " oldest row(s); ", .uucop_events$dropped, " dropped this process")
  }

  .uucop_events$queues[[key]] <- queue
  .uucop_start_flush_timer()
  .uucop_register_session_flush()

  # Write through immediately for the sessions tab. A session row is produced by
  # an onSessionEnded handler -- i.e. at the moment the session dies -- and
  # shinyapps.io suspends a worker once no client is connected, so a later()
  # tick scheduled after that point never runs and the row would be lost with
  # the process. Flushing here drains the whole queue, which also rescues the
  # trailing question/section events from the same session. One extra request
  # per student per session.
  if (sheet %in% getOption("uucop.write_through_tabs", "sessions")) {
    uucop_flush_events()
  }

  invisible(length(rows))
}

# Flush when the current Shiny session ends. Registered from the first append in
# each session so it applies to tutorials that carry their own inline
# log_session/recorder copies as well as those using session_tracking_server().
.uucop_register_session_flush <- function() {
  s <- tryCatch(shiny::getDefaultReactiveDomain(), error = function(e) NULL)
  if (is.null(s) || is.null(s$userData) || is.null(s$onSessionEnded)) {
    return(invisible(NULL))
  }
  if (isTRUE(s$userData$uucop_flush_hooked)) return(invisible(NULL))
  tryCatch({
    s$userData$uucop_flush_hooked <- TRUE
    s$onSessionEnded(function() uucop_flush_events())
  }, error = function(e) invisible(NULL))
  invisible(NULL)
}

#' Flush all buffered tutorial events to Google Sheets
#'
#' Writes every queued row, one `values.append` request per sheet tab. Safe to
#' call when the queue is empty (costs nothing). Called automatically by the
#' flush timer and by [session_tracking_server()] at session end; call it
#' directly only if you need an immediate write.
#'
#' Rows that fail with a retryable status (429 or 5xx, after gargle's own
#' retries) are put back at the front of the queue for the next flush. Rows
#' that fail permanently are dropped with a message rather than retried
#' forever.
#'
#' @return Invisibly, the number of rows successfully written.
#' @export
uucop_flush_events <- function() {
  if (isTRUE(.uucop_events$flushing)) return(invisible(0L))

  qs <- .uucop_events$queues
  if (!length(qs)) return(invisible(0L))

  .uucop_events$queues   <- list()
  .uucop_events$flushing <- TRUE
  on.exit(.uucop_events$flushing <- FALSE, add = TRUE)

  written <- 0L
  for (key in names(qs)) {
    rows <- qs[[key]]
    if (!length(rows)) next

    parts <- strsplit(key, "\r", fixed = TRUE)[[1]]
    ok <- .uucop_flush_one(parts[[1]], parts[[2]], rows)

    if (isTRUE(ok)) {
      written <- written + length(rows)
    } else if (identical(ok, NA)) {
      # Retryable failure -- put back ahead of anything queued mid-flush.
      .uucop_events$queues[[key]] <- c(rows, .uucop_events$queues[[key]])
    }
    # ok == FALSE: permanent failure, already reported; drop.
  }

  invisible(written)
}

# Write one tab's rows in a single request.
# Returns TRUE (written), NA (retryable -- requeue), or FALSE (drop).
.uucop_flush_one <- function(sheet_id, tab, rows) {
  token <- tryCatch(googlesheets4::gs4_token(), error = function(e) NULL)
  if (is.null(token)) {
    message("uucop: no Google Sheets token; ", length(rows),
            " event(s) held for the next flush")
    return(NA)
  }

  rng <- utils::URLencode(paste0("'", tab, "'!A1"), reserved = TRUE)

  req <- gargle::request_build(
    method = "POST",
    path   = "v4/spreadsheets/{spreadsheetId}/values/{range}:append",
    params = list(
      spreadsheetId    = sheet_id,
      range            = rng,
      valueInputOption = "RAW",
      insertDataOption = "INSERT_ROWS"
    ),
    body     = list(values = rows),
    token    = token,
    base_url = "https://sheets.googleapis.com"
  )

  resp <- tryCatch(
    gargle::request_retry(req, encode = "json"),
    error = function(e) e
  )

  if (inherits(resp, "error")) {
    message("uucop: flush to '", tab, "' failed (", conditionMessage(resp),
            "); ", length(rows), " event(s) held for the next flush")
    return(NA)
  }

  status <- httr::status_code(resp)
  if (status < 300) return(TRUE)

  if (status == 429L || status >= 500L) {
    message("uucop: flush to '", tab, "' got HTTP ", status, "; ",
            length(rows), " event(s) held for the next flush")
    return(NA)
  }

  message("uucop: flush to '", tab, "' rejected with HTTP ", status, "; ",
          length(rows), " event(s) dropped")
  FALSE
}

# data.frame -> list of rows, each a list of length-1 JSON-typed values.
# NA becomes NA_character_ so httr's encoder emits a positional `null`
# (an empty cell). NA_real_ would otherwise serialize as the string "NA".
.uucop_row_list <- function(df) {
  lapply(seq_len(nrow(df)), function(i) {
    lapply(seq_along(df), function(j) {
      v <- df[[j]][[i]]
      if (length(v) != 1L)                        return(NA_character_)
      if (is.na(v))                               return(NA_character_)
      if (inherits(v, c("POSIXct", "POSIXt", "Date"))) return(as.character(v))
      if (is.logical(v))                          return(as.logical(v))
      if (is.numeric(v))                          return(as.numeric(v))
      as.character(v)
    })
  })
}

# Self-rescheduling process-level flush timer. Jittered so that the ~20 worker
# processes shinyapps.io spins up for a class do not all flush on the same tick.
.uucop_start_flush_timer <- function() {
  if (isTRUE(.uucop_events$timer_live)) return(invisible(NULL))
  .uucop_events$timer_live <- TRUE

  interval <- function() {
    getOption("uucop.flush_seconds", 20) + stats::runif(1, 0, 5)
  }

  tick <- function() {
    tryCatch(uucop_flush_events(),
             error = function(e) message("uucop: flush error: ", e$message))
    later::later(tick, interval())
  }

  later::later(tick, interval())
  invisible(NULL)
}
