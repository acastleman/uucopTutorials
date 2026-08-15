# =============================================================================
# Batched, TTL-cached tab reads
# =============================================================================
# The Sheets API allows 60 read requests/minute *per user*, and every tutorial,
# lab, and dashboard authenticates as the same service account, so they all draw
# from one bucket. Two things make naive reads expensive:
#
#   1. read_sheet() costs TWO requests, not one: get_cells() calls gs4_get() for
#      metadata and then fetches the values.
#   2. Every session reads the same whole tabs and filters per user in R, so N
#      students cost N identical read sets.
#
# Two fixes, together ~30x fewer requests at the same concurrency:
#   * values.batchGet pulls every requested tab in ONE request, and skips the
#     metadata call entirely.
#   * A process-level TTL cache collapses concurrent students to one read set
#     per process per window. shinyapps.io runs several worker processes and
#     each has its own cache; the win scales with students-per-process.
#
# The cache holds RAW tab contents (all users), exactly as the sheet returned
# them. Per-user filtering happens downstream, so caching here cannot leak one
# student's rows into another's view.
#
# NOTE ON DUPLICATION: projects/StudentPortal/sheet_cache.R holds a near-
# identical implementation. It was left in place deliberately rather than
# refactored to depend on this package, because the portal is a separately
# deployed repo and this was written mid-semester. Reconcile the two when
# tutorial logging moves off Google Sheets.
# =============================================================================

.uucop_sheet_cache <- new.env(parent = emptyenv())

.uucop_cache_key <- function(sheet_id, tab) paste0(sheet_id, "___", tab)

# Returns the wrapper list(at=, value=) or NULL when absent/stale.
# NOT the value itself: a missing tab caches a NULL value, and that is a
# legitimate hit we must not re-request every load.
.uucop_cache_peek <- function(sheet_id, tab, ttl) {
  hit <- .uucop_sheet_cache[[.uucop_cache_key(sheet_id, tab)]]
  if (is.null(hit)) return(NULL)
  if (as.numeric(difftime(Sys.time(), hit$at, units = "secs")) > ttl) return(NULL)
  hit
}

.uucop_cache_put <- function(sheet_id, tab, value) {
  assign(.uucop_cache_key(sheet_id, tab),
         list(at = Sys.time(), value = value),
         envir = .uucop_sheet_cache)
  invisible(value)
}

#' Drop cached sheet tabs
#'
#' @param sheet_id Spreadsheet to clear. `NULL` clears everything.
#' @param tabs Specific tabs to clear. `NULL` clears every tab of `sheet_id`.
#' @return Invisibly, the number of cache entries dropped.
#' @export
uucop_cache_invalidate <- function(sheet_id = NULL, tabs = NULL) {
  keys <- ls(.uucop_sheet_cache, all.names = TRUE)
  drop <- if (is.null(sheet_id)) {
    keys
  } else if (is.null(tabs)) {
    keys[startsWith(keys, paste0(sheet_id, "___"))]
  } else {
    .uucop_cache_key(sheet_id, tabs)
  }
  drop <- intersect(drop, keys)
  if (length(drop)) rm(list = drop, envir = .uucop_sheet_cache)
  invisible(length(drop))
}

# ── Value parsing ────────────────────────────────────────────────────────────

# Convert a values.batchGet valueRange$values (list of row-lists) into the same
# shape read_sheet(col_types = "c") returns: an all-character data frame, header
# row as names, whitespace trimmed, blanks as NA.
#
# The API omits trailing empty cells, so rows are ragged and shorter than the
# header; length<- pads those with NA (and truncates any row that overruns).
.uucop_values_to_df <- function(values) {
  if (is.null(values) || length(values) == 0) return(NULL)

  hdr  <- trimws(as.character(unlist(values[[1]])))
  keep <- nzchar(hdr) & !is.na(hdr)
  if (!any(keep)) return(NULL)
  n <- length(hdr)

  rows <- values[-1]
  if (length(rows) == 0) {
    out <- as.data.frame(matrix(character(0), nrow = 0, ncol = sum(keep)),
                         stringsAsFactors = FALSE)
    names(out) <- hdr[keep]
    return(out)
  }

  mat <- vapply(rows, function(r) {
    v <- as.character(unlist(r))
    length(v) <- n
    v
  }, character(n))
  mat <- if (n == 1) matrix(mat, ncol = 1) else t(mat)

  out <- as.data.frame(mat, stringsAsFactors = FALSE)
  names(out) <- hdr
  out <- out[, keep, drop = FALSE]

  # read_sheet(col_types = "c") trims whitespace and yields NA for blank cells;
  # batchGet yields untrimmed strings and "". Match read_sheet so downstream
  # parsers behave identically.
  out[] <- lapply(out, function(x) {
    x <- trimws(x)
    x[!nzchar(x)] <- NA_character_
    x
  })
  rownames(out) <- NULL
  out
}

# ── Fetching ─────────────────────────────────────────────────────────────────

# One request for all requested tabs. gargle's compose_query() cannot encode a
# vector into repeated `ranges=` keys, so the query string is built by hand.
# googlesheets4::request_make() is gargle::request_retry(), so the 429 backoff
# still applies here.
.uucop_batch_read_tabs <- function(sheet_id, tabs) {
  req <- googlesheets4::request_generate(
    "sheets.spreadsheets.values.batchGet",
    params = list(spreadsheetId = sheet_id)
  )
  qs <- paste(c(
    paste0("ranges=", vapply(tabs, utils::URLencode, character(1), reserved = TRUE)),
    "majorDimension=ROWS",
    "valueRenderOption=FORMATTED_VALUE"
  ), collapse = "&")
  req$url <- paste0(sub("\\?.*$", "", req$url), "?", qs)

  out <- gargle::response_process(googlesheets4::request_make(req))
  vrs <- out$valueRanges
  if (length(vrs) != length(tabs)) {
    stop("batchGet returned ", length(vrs), " ranges for ", length(tabs), " tabs")
  }
  stats::setNames(lapply(vrs, function(vr) .uucop_values_to_df(vr$values)), tabs)
}

# Single-tab read via googlesheets4. Only used as the fallback path.
.uucop_single_read_tab <- function(sheet_id, tab) {
  tryCatch(
    as.data.frame(googlesheets4::read_sheet(sheet_id, sheet = tab, col_types = "c")),
    error = function(e) {
      message("uucop: could not load tab '", tab, "': ", conditionMessage(e))
      NULL
    }
  )
}

#' Read Google Sheet tabs in one batched, cached request
#'
#' Returns a named list, one element per tab (`NULL` if the tab is missing or
#' unreadable). Cached tabs cost nothing; the rest go out in a single
#' `values.batchGet`.
#'
#' `batchGet` is all-or-nothing: one bad range 400s the whole request, which is
#' the normal case for a sheet that has never had, say, a `section_events` tab.
#' On failure this falls back to per-tab reads, which tolerate a missing tab at
#' a cost of 2 requests each — so keep course sheets fully provisioned.
#'
#' @param sheet_id Google Sheet ID.
#' @param tabs Character vector of tab names.
#' @param ttl Seconds a cached tab stays fresh. The default suits per-session
#'   seeding, where staleness only matters across visits.
#' @return Named list of data frames (all character columns) or `NULL`s.
#' @export
uucop_read_tabs <- function(sheet_id, tabs, ttl = 120) {
  if (is.null(sheet_id) || length(sheet_id) != 1 || is.na(sheet_id) ||
      !nzchar(sheet_id)) {
    return(stats::setNames(vector("list", length(tabs)), tabs))
  }

  out    <- stats::setNames(vector("list", length(tabs)), tabs)
  misses <- character(0)

  for (tab in tabs) {
    hit <- .uucop_cache_peek(sheet_id, tab, ttl)
    if (is.null(hit)) misses <- c(misses, tab) else out[[tab]] <- hit$value
  }
  if (length(misses) == 0) return(out)

  fetched <- tryCatch(.uucop_batch_read_tabs(sheet_id, misses), error = function(e) {
    message("uucop: batchGet failed for ", sheet_id, " (", conditionMessage(e),
            ") - falling back to per-tab reads")
    stats::setNames(lapply(misses, function(tb) .uucop_single_read_tab(sheet_id, tb)),
                    misses)
  })

  for (tab in misses) {
    val <- fetched[[tab]]
    .uucop_cache_put(sheet_id, tab, val)
    out[[tab]] <- val
  }
  out
}
