#' Set up question event recording for learnr tutorials
#'
#' Installs a `tutorial.event_recorder` option that logs every question submission
#' to the `question_events` tab of the configured Google Sheet. Tracks attempt
#' number per user/question/day, captures answer text, and resolves the
#' authenticated user correctly on shinyapps.io.
#'
#' Call this in a `context="server-start"` chunk, after [setup_gs4_auth()].
#'
#' @param sheet_id Google Sheet ID. Defaults to `Sys.getenv("GS4_SHEET_ID")`.
#'
#' @details
#' **User identity:** The `user_id` argument passed to the recorder by learnr
#' resolves to the OS user (`'shiny'`) on shinyapps.io. This function uses
#' `shiny::getDefaultReactiveDomain()$user` instead, with a fallback chain:
#' `domain$user` -> `user_id` (if not 'shiny') -> `"unknown"`.
#'
#' **Attempt counting:** Maintains a process-level environment keyed by
#' `user___question___YYYYMMDD`. Resets each calendar day.
#'
#' @return Invisible `NULL`.
#' @export
setup_question_recorder <- function(sheet_id = Sys.getenv("GS4_SHEET_ID")) {
  # Process-level attempt counter
  .question_attempts <- new.env(parent = emptyenv())

  prior <- getOption("tutorial.event_recorder")

  options(tutorial.event_recorder = function(tutorial_id, tutorial_version,
                                             user_id, event, data) {
    # Chain to any prior recorder
    if (!is.null(prior)) {
      try(prior(tutorial_id, tutorial_version, user_id, event, data),
          silent = TRUE)
    }

    if (event != "question_submission") return(invisible(NULL))

    # Resolve real user identity
    domain    <- shiny::getDefaultReactiveDomain()
    real_user <- if (!is.null(domain) && !is.null(domain$user) && nzchar(domain$user)) {
      domain$user
    } else if (nzchar(user_id) && !identical(user_id, "shiny")) {
      user_id
    } else {
      "unknown"
    }

    # Count attempts per user/question/day
    key  <- paste0(real_user, "___", data$label, "___",
                   format(Sys.Date(), "%Y%m%d"))
    prev <- if (exists(key, envir = .question_attempts, inherits = FALSE)) {
      get(key, envir = .question_attempts)
    } else {
      0L
    }
    attempt <- prev + 1L
    assign(key, attempt, envir = .question_attempts)

    tryCatch({
      googlesheets4::sheet_append(
        sheet_id,
        data.frame(
          user                  = real_user,
          app                   = tutorial_id,
          date                  = format(Sys.time(), "%Y-%m-%d"),
          time                  = format(Sys.time(), "%H:%M:%S"),
          question              = data$label,
          attempt               = attempt,
          first_attempt_correct = (attempt == 1L) && isTRUE(data$correct),
          correct               = isTRUE(data$correct),
          answer_text           = if (!is.null(data$answer)) as.character(data$answer) else NA_character_,
          stringsAsFactors      = FALSE
        ),
        sheet = "question_events"
      )
    }, error = function(e) message("Question event log failed: ", e$message))
  })

  invisible(NULL)
}
