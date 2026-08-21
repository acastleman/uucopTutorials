# =============================================================================
# Live completion counter for the tutorial header
# =============================================================================
# Courses that grade on a "N questions AND M minutes" rule (PHRM 707 PASS uses
# 20/20) can show a student their standing without sending them to the Student
# Portal. Beyond convenience this is a diagnostic: an unauthenticated session
# logs nothing, and a header stuck at 0 surfaces that while it is still fixable.
#
# THE COUNT IS A UNION, NOT A SUM.
# Question events are buffered for ~20-25s before they reach the sheet (see
# event_buffer.R), so the sheet can never be re-read mid-session to refresh the
# number -- it would read rows that predate this session's work. Instead we read
# ONCE at session start for a seed, then union this session's labels onto it.
# A union of distinct labels is idempotent: replaying it, or overlapping it with
# a stale seed, cannot double-count. Adding counts would.
#
# THE METRIC MUST MATCH THE GRADER.
# courses/PHRM707_PASS/check_tutorial_completion.R produces the actual grades and
# projects/StudentPortal/app.R displays them. This is a third implementation of
# the same number, and a header that disagrees with a grade is worse than no
# header. Two rules keep them aligned, both mirrored from the grader:
#   * distinct question labels, excluding ^confidence_ (checkpoints log to
#     question_events too and are not questions)
#   * MCQ *and* free text, matching the portal's attempted_all -- never the
#     MCQ-only denominator, which no student could reach against a 20 target
# courses/PHRM707_PASS/verify_portal_parity.R diffs all three; run it before
# class.
# =============================================================================

# session$user is a full email address on shinyapps.io while rosters and the
# grader use the bare username. Canonicalize both sides identically.
.uucop_canon_user <- function(x) {
  tolower(trimws(sub("@.*$", "", as.character(x))))
}

# Does a sheet row's `app` value refer to this tutorial?
#
# The two tabs disagree about what `app` holds. `sessions.app` is the
# TUTORIAL_ID constant, but `question_events.app` is learnr's own tutorial_id --
# the deployment URL when deployed, the document path when run locally. So an
# equality test against TUTORIAL_ID silently matches nothing in question_events.
#
# Where the id carries a WK<n> token (the PASS convention) we match on that,
# exactly as app_to_week() does in check_tutorial_completion.R, which also makes
# legacy non-FC app names match their -FC replacements. Otherwise we fall back
# to a substring test, which is the correct generic treatment of a tutorial_id.
.uucop_app_matcher <- function(app_id) {
  key <- regmatches(app_id, regexpr("WK[0-9]+", app_id))
  if (length(key) && nzchar(key)) {
    # Trailing guard so WK1 does not match WK10.
    pat <- paste0(key, "([^0-9]|$)")
    function(sheet_app) grepl(pat, sheet_app)
  } else {
    function(sheet_app) grepl(app_id, sheet_app, fixed = TRUE)
  }
}

#' Prior progress for one student in one tutorial
#'
#' Reads the `question_events` and `sessions` tabs in a single cached
#' `values.batchGet` and returns what this student has already banked, across
#' every previous visit.
#'
#' @param sheet_id Google Sheet ID.
#' @param app_id This tutorial's id (the `TUTORIAL_ID` constant).
#' @param user The viewer's identity, as returned by [uucop_user()].
#' @param ttl Cache lifetime in seconds, passed to [uucop_read_tabs()].
#' @return A list with `labels` (distinct question labels attempted),
#'   `minutes` (cumulative session minutes), and `ok` -- `FALSE` when the read
#'   failed or the user could not be identified, in which case the caller must
#'   not present the result as a cumulative total.
#' @export
uucop_progress_snapshot <- function(sheet_id, app_id, user, ttl = 120) {
  out <- list(labels = character(0), minutes = 0, ok = FALSE)

  u <- .uucop_canon_user(user)
  if (!nzchar(u) || identical(u, "unknown")) return(out)

  tabs <- tryCatch(
    uucop_read_tabs(sheet_id, c("question_events", "sessions"), ttl = ttl),
    error = function(e) {
      message("uucop: progress seed read failed: ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(tabs)) return(out)

  qe <- tabs[["question_events"]]
  se <- tabs[["sessions"]]

  # A NULL question_events means the tab is missing or unreadable. We cannot
  # verify a cumulative count, so report failure rather than an implied zero.
  if (!is.data.frame(qe) || !all(c("user", "app", "question") %in% names(qe))) {
    return(out)
  }

  matches <- .uucop_app_matcher(app_id)

  keep <- .uucop_canon_user(qe$user) == u &
    matches(as.character(qe$app)) &
    !is.na(qe$question) &
    !grepl("^confidence_", qe$question)
  keep[is.na(keep)] <- FALSE
  out$labels <- unique(as.character(qe$question[keep]))

  if (is.data.frame(se) && all(c("user", "app", "duration_min") %in% names(se))) {
    skeep <- .uucop_canon_user(se$user) == u & matches(as.character(se$app))
    skeep[is.na(skeep)] <- FALSE
    mins <- suppressWarnings(as.numeric(se$duration_min[skeep]))
    out$minutes <- sum(mins, na.rm = TRUE)
  }

  out$ok <- TRUE
  out
}

#' Send the current progress state to the tutorial header
#'
#' A no-op unless [uucop_progress_server()] set up state for this session.
#' Cheap -- one websocket message, no API call.
#'
#' @param session A Shiny session object.
#' @return Invisible `NULL`.
#' @export
uucop_progress_push <- function(session = shiny::getDefaultReactiveDomain()) {
  if (is.null(session) || is.null(session$userData)) return(invisible(NULL))
  st <- session$userData$uucop_progress
  if (is.null(st)) return(invisible(NULL))

  answered <- length(st$labels)
  elapsed  <- as.numeric(difftime(Sys.time(), st$started, units = "mins"))
  minutes  <- st$seed_minutes + elapsed

  # The CLIENT decides when the time half flips, from the milliseconds we send
  # it here. This used to be a 30-second `invalidateLater` re-push, which also
  # kept the websocket busy for the whole life of the session -- so
  # `application.shiny.timeout.conn` (900 s) never fired, the instance never
  # went idle, and an abandoned tab billed active hours all night. Measured:
  # PASS-WK2 billed 12 consecutive hours 2026-08-19 20:00 -> 2026-08-20 07:00
  # CDT. Zero such overnight runs existed before this timer shipped.
  # See shinyapps_idle_timeout_TODO.md.
  #
  # We send REMAINING MILLISECONDS, not an absolute instant, so client/server
  # clock skew cannot make the chip flip early or never.
  remaining_ms <- max(0, (st$min_minutes - minutes) * 60 * 1000)

  # `minutes` is deliberately NOT sent to the client. Publishing "12 / 20 min"
  # tells every student the time half of the rule is satisfiable by leaving the
  # tab open. `minutesMet` is a bare boolean -- it says no more than the
  # completion chip already says, and the client needs it to decide whether to
  # draw that chip against its own (possibly higher) count.
  #
  # We send the LABELS, not just their number. Two latencies sit between a
  # submission and what a fresh page load can read back: the ~20-25s event
  # buffer, and the per-worker read cache in uucop_read_tabs(). Those caches are
  # independent -- shinyapps.io spreads reloads across worker processes, each
  # holding its own snapshot -- so a bare count can go DOWN on reload, which
  # reads as broken. The client unions these labels into its own stored set, so
  # its displayed count only ever rises. as.list() keeps a length-1 vector from
  # serializing as a bare string instead of an array.
  msg <- list(
    labels     = as.list(st$labels),
    answered   = answered,
    target     = st$min_questions,
    cumulative = isTRUE(st$seeded),
    identified = isTRUE(st$identified),
    minutesMet = minutes >= st$min_minutes,
    # Older per-tutorial copies of www/uucop-tutorial.js ignore this and fall
    # back to the boolean above, which is correct at push time -- they just do
    # not flip the chip until the next push. Nothing breaks; keep both.
    minutesInMs = remaining_ms,
    complete   = isTRUE(st$seeded) &&
      answered >= st$min_questions &&
      minutes  >= st$min_minutes
  )

  try(session$sendCustomMessage("uucop_progress", msg), silent = TRUE)
  invisible(NULL)
}

#' Record a question label against this session's progress count
#'
#' Called by [setup_question_recorder()] on every submission. Safe to call when
#' no progress counter is running.
#'
#' @param session A Shiny session object.
#' @param label The question label from the event payload.
#' @return Invisible `NULL`.
#' @export
uucop_progress_note <- function(session, label) {
  if (is.null(session) || is.null(session$userData)) return(invisible(NULL))
  st <- session$userData$uucop_progress
  if (is.null(st)) return(invisible(NULL))
  if (is.null(label) || !nzchar(label) || grepl("^confidence_", label)) {
    return(invisible(NULL))
  }

  st$session_labels <- union(st$session_labels, label)
  st$labels         <- union(st$labels, label)
  session$userData$uucop_progress <- st

  uucop_progress_push(session)
  invisible(NULL)
}

#' Show a live questions-answered counter in the tutorial header
#'
#' Call once from a `context="server"` chunk. The counter renders in the header
#' injected by `www/uucop-tutorial.js`, and only when that file's `uucop-config`
#' block carries a `progress` key -- so adding this call to a tutorial whose
#' config lacks one changes nothing on screen.
#'
#' The client fires `uucop_progress_ready` once its header exists; that
#' handshake is what triggers the seed read, and it removes the race where the
#' server would otherwise push before the message handler is registered.
#'
#' @param app_id This tutorial's id (the `TUTORIAL_ID` constant).
#' @param sheet_id Google Sheet ID. Defaults to `Sys.getenv("GS4_SHEET_ID")`.
#' @param min_questions Distinct questions required for completion.
#' @param min_minutes Cumulative minutes required for completion.
#' @param session A Shiny session object.
#' @param user The student to count for. Defaults to the authenticated viewer.
#'   Override only to test the authenticated path locally, where `session$user`
#'   is `NULL` and the header would otherwise stay in its "not signed in" state.
#' @return Invisible `NULL`.
#' @export
uucop_progress_server <- function(app_id,
                                  sheet_id      = Sys.getenv("GS4_SHEET_ID"),
                                  min_questions = 20,
                                  min_minutes   = 20,
                                  session       = shiny::getDefaultReactiveDomain(),
                                  user          = uucop_user(session)) {
  if (is.null(session)) return(invisible(NULL))

  session$userData$uucop_progress <- list(
    app_id         = app_id,
    sheet_id       = sheet_id,
    min_questions  = min_questions,
    min_minutes    = min_minutes,
    started        = Sys.time(),
    labels         = character(0),   # seed union this session
    session_labels = character(0),   # this session alone
    seed_minutes   = 0,
    seeded         = FALSE,
    user           = user,
    identified     = !identical(user, "unknown")
  )

  shiny::observeEvent(session$input$uucop_progress_ready, {
    st <- session$userData$uucop_progress
    if (is.null(st)) return()

    if (isTRUE(st$identified)) {
      snap <- uucop_progress_snapshot(st$sheet_id, st$app_id, st$user)
      if (isTRUE(snap$ok)) {
        st$seeded       <- TRUE
        st$seed_minutes <- snap$minutes
        # Union, not replace: questions answered between session start and the
        # seed landing must survive.
        st$labels       <- union(snap$labels, st$session_labels)
      }
      session$userData$uucop_progress <- st
    }

    uucop_progress_push(session)
  }, once = TRUE)

  # NO recurring timer here. Pushes are event-driven only: once on the client's
  # `uucop_progress_ready` handshake (above) and once per answered question via
  # uucop_progress_note(). The time half of the rule flips client-side off the
  # `minutesInMs` countdown in uucop_progress_push().
  #
  # A `shiny::invalidateLater(30000, session)` observe used to live here. It
  # cost no API calls but generated 120 websocket messages an hour for the
  # lifetime of every session, which stopped the connection from ever looking
  # idle and so stopped shinyapps.io from ever reclaiming the instance.
  # Do not reintroduce a heartbeat here.

  invisible(NULL)
}
