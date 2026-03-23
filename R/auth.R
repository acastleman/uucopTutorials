#' Authenticate with Google Sheets via service account
#'
#' Looks for the service account JSON in the standard locations:
#' 1. `secrets/gs4-service-account.json` (deployed app)
#' 2. A local fallback path (development)
#'
#' @param app_json Path to the deployed service account JSON.
#'   Defaults to `"secrets/gs4-service-account.json"`.
#' @param local_json Fallback path for local development.
#'   Defaults to a path 2 levels up from the working directory, then into `.secrets/`.
#'   Set to `NULL` to skip the fallback.
#'
#' @return Invisible `TRUE` if authentication succeeded, `FALSE` otherwise.
#' @export
setup_gs4_auth <- function(app_json = "secrets/gs4-service-account.json",
                           local_json = NULL) {
  if (is.null(local_json)) {
    local_json <- normalizePath(
      file.path("..", "..", ".secrets", "gs4-service-account.json"),
      mustWork = FALSE
    )
  }

  if (file.exists(app_json)) {
    googlesheets4::gs4_auth(path = app_json)
    return(invisible(TRUE))
  } else if (file.exists(local_json)) {
    googlesheets4::gs4_auth(path = local_json)
    return(invisible(TRUE))
  }

  message("GS4 service account JSON not found at:\n  ", app_json, "\n  ", local_json)
  invisible(FALSE)
}
