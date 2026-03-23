#' Set up all tracking infrastructure for a learnr tutorial
#'
#' Convenience function that calls [setup_gs4_auth()] and
#' [setup_question_recorder()] in a single call. Use this in a
#' `context="server-start"` chunk to replace all boilerplate.
#'
#' @param app_id The app/tutorial identifier string (e.g., `"PC2-SolutionsPart1"`).
#'   Used by the session and section tracking functions called separately in
#'   the `context="server"` chunk.
#' @param sheet_id Google Sheet ID. Defaults to `Sys.getenv("GS4_SHEET_ID")`.
#' @param app_json Path to the deployed service account JSON.
#' @param local_json Fallback path for local development. `NULL` uses the default.
#'
#' @details
#' This function handles `context="server-start"` setup. You still need to call
#' [session_tracking_server()], [section_tracking_server()], and optionally
#' [feedback_form_server()] in a `context="server"` chunk.
#'
#' @section Minimal tutorial boilerplate:
#' ```
#' # In context="server-start" chunk:
#' uucopTutorials::setup_tracking(
#'   app_id   = "MyApp-Tutorial1",
#'   sheet_id = Sys.getenv("GS4_SHEET_ID")
#' )
#'
#' # In context="server" chunk:
#' uucopTutorials::session_tracking_server("MyApp-Tutorial1")
#' uucopTutorials::section_tracking_server("MyApp-Tutorial1")
#' uucopTutorials::feedback_form_server("MyApp-Tutorial1", "My Tutorial Title")
#' ```
#'
#' @return Invisible `NULL`.
#' @export
setup_tracking <- function(app_id,
                           sheet_id   = Sys.getenv("GS4_SHEET_ID"),
                           app_json   = "secrets/gs4-service-account.json",
                           local_json = NULL) {
  setup_gs4_auth(app_json = app_json, local_json = local_json)
  setup_question_recorder(sheet_id = sheet_id)
  invisible(NULL)
}
