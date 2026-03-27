#' Feedback form UI for learnr tutorials
#'
#' Renders the standard UUCOP feedback form: category selector, section selector,
#' text area, submit button, and status output.
#'
#' @param sections Character vector of section names for the section selector.
#'   The first element should be `"General / Whole tutorial"`.
#' @param placeholder Placeholder text for the feedback text area.
#'
#' @return A [shiny::tagList()] of UI elements. Place in a `{r echo=FALSE}` chunk.
#' @export
feedback_form_ui <- function(
    sections = c("General / Whole tutorial"),
    placeholder = "e.g. 'The explanation was unclear.' or 'Typo in the calculation steps.'"
) {
  shiny::tagList(
    shiny::selectInput(
      "feedback_category",
      "What type of feedback?",
      choices = c(
        "Select a category...",
        "Factual error \u2014 content is wrong",
        "Level mismatch \u2014 too detailed or not detailed enough",
        "Conceptual gap \u2014 prerequisite concept missing",
        "Clarity issue \u2014 accurate but confusing",
        "Question design \u2014 distractor or stem issue",
        "Positive \u2014 worth keeping",
        "Other"
      ),
      width = "350px"
    ),
    shiny::selectInput(
      "feedback_section",
      "Which section does this apply to?",
      choices = sections,
      width = "350px"
    ),
    shiny::textAreaInput(
      "feedback_text",
      "Describe your feedback:",
      rows = 4,
      placeholder = placeholder,
      width = "100%"
    ),
    shiny::actionButton(
      "submit_feedback",
      "Send Feedback",
      class = "btn-default",
      style = "margin-top:6px;"
    ),
    shiny::uiOutput("feedback_status")
  )
}

#' Feedback form server logic for learnr tutorials
#'
#' Handles the submit button, sends email via blastula, and renders status.
#' Call in a `context="server"` chunk.
#'
#' **Important:** Pass `input` and `output` explicitly when calling from a learnr
#' server chunk. The default `parent.frame()` resolution is unreliable in learnr's
#' execution context. Example:
#' `feedback_form_server(TUTORIAL_ID, "Title", input = input, output = output)`.
#'
#' @param app_id The app/tutorial identifier string.
#' @param tutorial_title Human-readable tutorial title for the email subject.
#' @param to Instructor email address. Defaults to `"acastleman@uu.edu"`.
#' @param session The Shiny session object.
#' @param input The Shiny input object. Must be passed explicitly in learnr.
#' @param output The Shiny output object. Must be passed explicitly in learnr.
#'
#' @return Invisible `NULL`.
#' @export
feedback_form_server <- function(app_id, tutorial_title,
                                 to = "acastleman@uu.edu",
                                 session = shiny::getDefaultReactiveDomain(),
                                 input,
                                 output) {
  output$feedback_status <- shiny::renderUI(NULL)

  shiny::observeEvent(input$submit_feedback, {
    category <- input$feedback_category
    section  <- input$feedback_section
    text     <- trimws(input$feedback_text)

    if (identical(category, "Select a category...") || nchar(text) == 0) {
      output$feedback_status <- shiny::renderUI(
        shiny::tags$p(
          style = "color:#721c24; margin-top:8px;",
          "Please select a category and describe your feedback before sending."
        )
      )
      return()
    }

    student_id <- if (!is.null(session$user) && nzchar(session$user)) {
      session$user
    } else {
      "Unknown"
    }

    student_email <- if (!identical(student_id, "Unknown")) {
      if (grepl("@", student_id)) student_id else paste0(student_id, "@my.uu.edu")
    } else {
      character(0)
    }

    body_html <- paste0(
      '<div style="font-family:Arial,Helvetica,sans-serif;max-width:680px;color:#222;">',
      '<h2 style="color:#003366;border-bottom:2px solid #003366;padding-bottom:6px;">',
      htmltools::htmlEscape(tutorial_title), ' \u2014 Student Feedback</h2>',
      '<p><strong>Student:</strong> ', htmltools::htmlEscape(student_id), '</p>',
      '<p><strong>Submitted:</strong> ', format(Sys.time(), "%Y-%m-%d %H:%M:%S"), '</p>',
      '<p><strong>Category:</strong> ', htmltools::htmlEscape(category), '</p>',
      '<p><strong>Section:</strong> ', htmltools::htmlEscape(section), '</p>',
      '<p><strong>Feedback:</strong></p>',
      '<blockquote style="border-left:3px solid #003366;padding:8px 12px;margin:8px 0;background:#f9f9f9;">',
      htmltools::htmlEscape(text),
      '</blockquote>',
      '</div>'
    )

    fb_result <- smtp_send_html(
      html_body = body_html,
      to        = to,
      subject   = sprintf("%s Feedback \u2014 %s \u2014 %s",
                          tutorial_title, category, format(Sys.time(), "%Y-%m-%d")),
      cc        = student_email
    )

    output$feedback_status <- shiny::renderUI(
      render_send_status(
        success     = identical(fb_result, "success"),
        success_msg = "\u2713 Feedback sent \u2014 thank you!",
        error_detail = if (identical(fb_result, "success")) "" else fb_result,
        fail_prefix  = "Feedback could not be sent \u2014 please email the instructor directly."
      )
    )
  })

  invisible(NULL)
}

#' Question form UI for learnr tutorials (freeform, no category/section)
#'
#' A simplified submission form for sending a freeform question to the
#' instructor. Unlike [feedback_form_ui()], there is no category or section
#' dropdown. Use this in PC2 and PBDA1 tutorials where the student asks a
#' direct question rather than filing structured feedback.
#'
#' @param label Label for the text area. Defaults to `"Your question:"`.
#' @param placeholder Placeholder text. Defaults to a generic example.
#' @param button_label Label for the submit button.
#'
#' @return A [shiny::tagList()] of UI elements.
#' @export
question_form_ui <- function(
    label        = "Your question:",
    placeholder  = "e.g. 'I don\u2019t understand why pH affects solubility here.'",
    button_label = "Send Question"
) {
  shiny::tagList(
    shiny::textAreaInput(
      "student_question",
      label,
      rows        = 4,
      placeholder = placeholder,
      width       = "100%"
    ),
    shiny::actionButton(
      "submit_question",
      button_label,
      class = "btn-default",
      style = "margin-top:6px;"
    ),
    shiny::uiOutput("question_status")
  )
}

#' Question form server logic for learnr tutorials
#'
#' Handles the submit button for [question_form_ui()], sends the question via
#' email, and renders a status message. Call in a `context="server"` chunk.
#'
#' **Important:** Pass `input` and `output` explicitly — `parent.frame()`
#' resolution is unreliable in learnr's execution context.
#'
#' @param app_id The app/tutorial identifier string.
#' @param tutorial_title Human-readable tutorial title for the email subject.
#' @param to Instructor email address. Defaults to `"acastleman@uu.edu"`.
#' @param session The Shiny session object.
#' @param input The Shiny input object. Must be passed explicitly in learnr.
#' @param output The Shiny output object. Must be passed explicitly in learnr.
#'
#' @return Invisible `NULL`.
#' @export
question_form_server <- function(app_id, tutorial_title,
                                  to      = "acastleman@uu.edu",
                                  session = shiny::getDefaultReactiveDomain(),
                                  input,
                                  output) {
  output$question_status <- shiny::renderUI(NULL)

  shiny::observeEvent(input$submit_question, {
    text <- trimws(input$student_question)

    if (nchar(text) == 0) {
      output$question_status <- shiny::renderUI(
        shiny::tags$p(
          style = "color:#721c24; margin-top:8px;",
          "Please type your question before sending."
        )
      )
      return()
    }

    student_id    <- if (!is.null(session$user) && nzchar(session$user)) session$user else "unknown"
    student_email <- derive_student_email(student_id)

    body_html <- paste0(
      '<div style="font-family:Arial,Helvetica,sans-serif;max-width:680px;color:#222;">',
      '<h2 style="color:#003366;border-bottom:2px solid #003366;padding-bottom:6px;">',
      htmltools::htmlEscape(tutorial_title), ' \u2014 Student Question</h2>',
      '<p><strong>Student:</strong> ', htmltools::htmlEscape(student_id), '</p>',
      '<p><strong>Submitted:</strong> ', format(Sys.time(), "%Y-%m-%d %H:%M:%S"), '</p>',
      '<p><strong>Question:</strong></p>',
      '<blockquote style="border-left:3px solid #003366;padding:8px 12px;margin:8px 0;background:#f9f9f9;">',
      htmltools::htmlEscape(text),
      '</blockquote>',
      '</div>'
    )

    q_result <- smtp_send_html(
      html_body = body_html,
      to        = to,
      subject   = sprintf("%s \u2014 Student Question \u2014 %s \u2014 %s",
                          tutorial_title, student_id, format(Sys.time(), "%Y-%m-%d")),
      cc        = student_email
    )

    output$question_status <- shiny::renderUI(
      render_send_status(
        success      = identical(q_result, "success"),
        success_msg  = "\u2713 Question sent \u2014 thank you!",
        error_detail = if (identical(q_result, "success")) "" else q_result,
        fail_prefix  = "Could not send \u2014 please email the instructor directly."
      )
    )
  })

  invisible(NULL)
}
