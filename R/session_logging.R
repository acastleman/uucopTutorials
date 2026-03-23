#' Log a tutorial session to Google Sheets
#'
#' Appends a row to the `sessions` tab of the configured Google Sheet.
#' Called automatically by [session_tracking_server()].
#'
#' @param user The authenticated username.
#' @param app_name The app/tutorial identifier string (e.g., `"PC2-SolutionsPart1"`).
#' @param start POSIXct start time of the session.
#' @param duration_min Numeric session duration in minutes.
#' @param sheet_id Google Sheet ID. Defaults to `Sys.getenv("GS4_SHEET_ID")`.
#'
#' @return Invisible `NULL`. Logs errors to message output.
#' @keywords internal
log_session <- function(user, app_name, start, duration_min,
                        sheet_id = Sys.getenv("GS4_SHEET_ID")) {
  tryCatch({
    googlesheets4::sheet_append(
      sheet_id,
      data.frame(
        user         = if (nzchar(user)) user else "unknown",
        app          = app_name,
        date         = format(start, "%Y-%m-%d"),
        start_time   = format(start, "%H:%M:%S"),
        duration_min = round(duration_min, 2),
        stringsAsFactors = FALSE
      ),
      sheet = "sessions"
    )
  }, error = function(e) message("Session log failed: ", e$message))
  invisible(NULL)
}

#' Set up session time tracking in a learnr tutorial
#'
#' Call this in a `context="server"` chunk. It records the session start time
#' and registers an `onSessionEnded` callback that logs the session duration.
#'
#' @param app_id The app/tutorial identifier string (e.g., `"PC2-SolutionsPart1"`).
#' @param session The Shiny session object. Defaults to the current session.
#'
#' @return Invisible `NULL`.
#' @export
session_tracking_server <- function(app_id, session = shiny::getDefaultReactiveDomain()) {

  session_start <- Sys.time()
  session_user  <- if (!is.null(session$user) && nzchar(session$user)) {
    session$user
  } else {
    "unknown"
  }

  session$onSessionEnded(function() {
    duration_min <- as.numeric(difftime(Sys.time(), session_start, units = "mins"))
    log_session(session_user, app_id, session_start, duration_min)
  })

  invisible(NULL)
}
