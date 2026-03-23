#' Create tracking tabs in a Google Sheet
#'
#' One-time setup function that creates the `sessions`, `question_events`, and
#' `section_events` tabs in the specified Google Sheet with correct headers.
#' Skips tabs that already exist.
#'
#' Requires `gs4_auth()` to have been called first.
#'
#' @param sheet_id Google Sheet ID.
#'
#' @return Invisible `NULL`.
#' @export
setup_tracking_sheets <- function(sheet_id) {
  ss       <- googlesheets4::gs4_get(sheet_id)
  existing <- googlesheets4::sheet_names(ss)

  tabs <- list(
    sessions = data.frame(
      user = character(), app = character(), date = character(),
      start_time = character(), duration_min = numeric()
    ),
    question_events = data.frame(
      user = character(), app = character(), date = character(),
      time = character(), question = character(),
      attempt = integer(), first_attempt_correct = logical(),
      correct = logical(), answer_text = character()
    ),
    section_events = data.frame(
      user = character(), app = character(), date = character(),
      section = character(), entered_at = character()
    )
  )

  for (tab_name in names(tabs)) {
    if (tab_name %in% existing) {
      message("  SKIP \u2014 tab already exists: ", tab_name)
    } else {
      googlesheets4::sheet_add(ss, tab_name)
      googlesheets4::sheet_write(tabs[[tab_name]], ss, sheet = tab_name)
      message("  Created tab: ", tab_name)
    }
  }
  message("Sheet setup complete: ", sheet_id)
  invisible(NULL)
}
