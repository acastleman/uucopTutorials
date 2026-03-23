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
#' @param app_id The app/tutorial identifier string.
#' @param tutorial_title Human-readable tutorial title for the email subject.
#' @param to Instructor email address. Defaults to `"acastleman@uu.edu"`.
#' @param session The Shiny session object.
#' @param input The Shiny input object.
#' @param output The Shiny output object.
#'
#' @return Invisible `NULL`.
#' @export
feedback_form_server <- function(app_id, tutorial_title,
                                 to = "acastleman@uu.edu",
                                 session = shiny::getDefaultReactiveDomain(),
                                 input = parent.frame()$input,
                                 output = parent.frame()$output) {
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

    fb_email <- blastula::compose_email(body = blastula::md(body_html))

    fb_result <- tryCatch({
      blastula::smtp_send(
        email       = fb_email,
        to          = to,
        from        = Sys.getenv("SMTP_USER"),
        cc          = student_email,
        subject     = sprintf("%s Feedback \u2014 %s \u2014 %s",
                              tutorial_title, category,
                              format(Sys.time(), "%Y-%m-%d")),
        credentials = blastula::creds_envvar(
          user        = Sys.getenv("SMTP_USER"),
          pass_envvar = "SMTP_PASS",
          host        = "smtp.gmail.com",
          port        = 465,
          use_ssl     = TRUE
        )
      )
      "success"
    }, error = function(e) conditionMessage(e))

    if (identical(fb_result, "success")) {
      output$feedback_status <- shiny::renderUI(
        shiny::tags$div(
          style = "background:#d4edda;border:1px solid #c3e6cb;padding:12px 15px;border-radius:5px;margin-top:12px;",
          shiny::tags$p(style = "color:#155724;margin:0;", "\u2713 Feedback sent \u2014 thank you!")
        )
      )
    } else {
      output$feedback_status <- shiny::renderUI(
        shiny::tags$div(
          style = "background:#f8d7da;border:1px solid #f5c6cb;padding:12px 15px;border-radius:5px;margin-top:12px;",
          shiny::tags$p(style = "color:#721c24;margin:0;",
                        paste("Feedback could not be sent \u2014 please email the instructor directly.",
                              fb_result))
        )
      )
    }
  })

  invisible(NULL)
}
