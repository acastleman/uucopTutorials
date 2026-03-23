# Tracking Infrastructure — Learnr Tutorials

Full implementation code for session logging, question event tracking, section navigation, student feedback, question submission, confidence calibration, and student-generated MCQ exercises. Copy these chunks into new tutorials and update the tutorial-specific values.

Reference implementation: `Pharmaceutics 2 Lecture/tutorials/01_solutions_part1/solutions_part1_tutorial.Rmd`

---

## server-start chunk (gs4-setup)

Runs once when the R process starts. Authenticates with Google Sheets, defines `log_session()`, and sets up the question event recorder.

```r
```{r gs4-setup, context="server-start"}
local({
  app_json   <- "secrets/gs4-service-account.json"
  # Adjust depth to reach .secrets/ at repo root: ../../ for 2-level, ../../../ for 3-level
  local_json <- normalizePath("../../../.secrets/gs4-service-account.json", mustWork = FALSE)
  if (file.exists(app_json)) {
    gs4_auth(path = app_json)
  } else if (file.exists(local_json)) {
    gs4_auth(path = local_json)
  }
})

TUTORIAL_ID <- "CourseCode-TutorialName"  # e.g., "PC2-Solutions-Part1"

# Register www/ at a stable URL prefix so static assets resolve correctly.
# Guard against missing directory (e.g., fresh clone before assets are added).
if (dir.exists("www")) shiny::addResourcePath("media", "www")

log_session <- function(user, app_name, start, duration_min) {
  tryCatch({
    googlesheets4::sheet_append(
      Sys.getenv("GS4_SHEET_ID"),
      data.frame(user         = if (nzchar(user)) user else "unknown",
                 app          = app_name,
                 date         = format(start, "%Y-%m-%d"),
                 start_time   = format(start, "%H:%M:%S"),
                 duration_min = round(duration_min, 2),
                 stringsAsFactors = FALSE),
      sheet = "sessions"
    )
  }, error = function(e) message("Session log failed: ", e$message))
}

# Question attempt tracking
# Uses options(tutorial.event_recorder = ...) — more reliable than
# event_register_handler across learnr 0.10.x/0.11.x on shinyapps.io.
# user_id from learnr resolves to OS user ('shiny') on shinyapps.io;
# pull authenticated user from reactive domain instead.
.question_attempts <- new.env(parent = emptyenv())

local({
  prior <- getOption("tutorial.event_recorder")
  options(tutorial.event_recorder = function(tutorial_id, tutorial_version,
                                             user_id, event, data) {
    if (!is.null(prior))
      try(prior(tutorial_id, tutorial_version, user_id, event, data),
          silent = TRUE)

    if (event != "question_submission") return(invisible(NULL))

    domain    <- shiny::getDefaultReactiveDomain()
    real_user <- if (!is.null(domain) && !is.null(domain$user) && nzchar(domain$user))
                   domain$user
                 else if (nzchar(user_id) && !identical(user_id, "shiny"))
                   user_id
                 else "unknown"

    key  <- paste0(real_user, "___", data$label, "___", format(Sys.Date(), "%Y%m%d"))
    prev <- if (exists(key, envir = .question_attempts, inherits = FALSE))
               get(key, envir = .question_attempts) else 0L
    attempt <- prev + 1L
    assign(key, attempt, envir = .question_attempts)

    tryCatch({
      googlesheets4::sheet_append(
        Sys.getenv("GS4_SHEET_ID"),
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
})
```
```

---

## server chunk (session + section + feedback + question submission + confidence + MCQ)

Runs once per session. Uses `TUTORIAL_ID` defined in server-start. Update section names in the feedback `selectInput`, confidence IDs, and email subject lines to match the actual tutorial.

**Important:** All user-supplied text in email HTML must be escaped with `htmltools::htmlEscape()` to prevent XSS. The unknown-user string must be lowercase `"unknown"` consistently (not `"Unknown"`).

```r
```{r feedback-server, context="server"}
# Session time tracking
session_start <- Sys.time()
session_user  <- if (!is.null(session$user) && nzchar(session$user)) session$user else "unknown"
session$onSessionEnded(function() {
  duration_min <- as.numeric(difftime(Sys.time(), session_start, units = "mins"))
  log_session(session_user, TUTORIAL_ID, session_start, duration_min)
})

# Section navigation tracking
observeEvent(input$learnr_section, {
  sec_data <- input$learnr_section
  tryCatch({
    googlesheets4::sheet_append(
      Sys.getenv("GS4_SHEET_ID"),
      data.frame(
        user       = session_user,
        app        = TUTORIAL_ID,
        date       = format(Sys.time(), "%Y-%m-%d"),
        section    = sec_data$section,
        entered_at = sec_data$timestamp
      ),
      sheet = "section_events"
    )
  }, error = function(e) message("Section event log failed: ", e$message))
})

# Question submission to faculty
output$question_status <- renderUI(NULL)

observeEvent(input$submit_question, {
  text <- trimws(input$student_question)
  if (nchar(text) == 0) {
    output$question_status <- renderUI(
      tags$p(style = "color:#721c24; margin-top:8px;",
             "Please type your question before sending.")
    )
    return()
  }

  now           <- Sys.time()
  student_id    <- if (!is.null(session$user) && nzchar(session$user)) session$user else "unknown"
  student_email <- if (!identical(student_id, "unknown")) {
    if (grepl("@", student_id)) student_id else paste0(student_id, "@my.uu.edu")
  } else character(0)

  body_html <- paste0(
    '<div style="font-family:Arial,Helvetica,sans-serif;max-width:680px;color:#222;">',
    '<h2 style="color:#003366;border-bottom:2px solid #003366;padding-bottom:6px;">',
    'Student Question \u2014 TUTORIAL_NAME</h2>',
    '<p><strong>Student:</strong> ', htmltools::htmlEscape(student_id), '</p>',
    '<p><strong>Submitted:</strong> ', format(now, "%Y-%m-%d %H:%M:%S"), '</p>',
    '<p><strong>Question:</strong></p>',
    '<blockquote style="border-left:3px solid #003366;padding:8px 12px;margin:8px 0;background:#f9f9f9;">',
    htmltools::htmlEscape(text), '</blockquote></div>'
  )

  q_email  <- blastula::compose_email(body = blastula::md(body_html))
  q_result <- tryCatch({
    blastula::smtp_send(
      email       = q_email,
      to          = "acastleman@uu.edu",
      from        = Sys.getenv("SMTP_USER"),
      cc          = student_email,
      subject     = sprintf("Student Question \u2014 TUTORIAL_SHORT_NAME \u2014 %s",
                            format(now, "%Y-%m-%d")),
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

  if (identical(q_result, "success")) {
    output$question_status <- renderUI(
      tags$div(
        style = "background:#d4edda;border:1px solid #c3e6cb;padding:12px 15px;border-radius:5px;margin-top:12px;",
        tags$p(style = "color:#155724;margin:0;", "\u2713 Question sent \u2014 thank you!")
      )
    )
  } else {
    output$question_status <- renderUI(
      tags$div(
        style = "background:#f8d7da;border:1px solid #f5c6cb;padding:12px 15px;border-radius:5px;margin-top:12px;",
        tags$p(style = "color:#721c24;margin:0;",
               paste("Could not send \u2014 please email Dr. Castleman directly.", q_result))
      )
    )
  }
})

# Feedback form handler
observeEvent(input$submit_feedback, {
  category <- input$feedback_category
  section  <- input$feedback_section
  text     <- trimws(input$feedback_text)

  if (identical(category, "Select a category...") || nchar(text) == 0) {
    output$feedback_status <- renderUI(
      tags$p(style = "color:#721c24; margin-top:8px;",
             "Please select a category and describe your feedback before sending.")
    )
    return()
  }

  now           <- Sys.time()
  student_id    <- if (!is.null(session$user) && nzchar(session$user)) session$user else "unknown"
  student_email <- if (!identical(student_id, "unknown")) {
    if (grepl("@", student_id)) student_id else paste0(student_id, "@my.uu.edu")
  } else character(0)

  body_html <- paste0(
    '<div style="font-family:Arial,Helvetica,sans-serif;max-width:680px;color:#222;">',
    '<h2 style="color:#003366;border-bottom:2px solid #003366;padding-bottom:6px;">',
    'Tutorial Feedback \u2014 TUTORIAL_NAME</h2>',
    '<p><strong>Student:</strong> ', htmltools::htmlEscape(student_id), '</p>',
    '<p><strong>Submitted:</strong> ', format(now, "%Y-%m-%d %H:%M:%S"), '</p>',
    '<p><strong>Category:</strong> ', htmltools::htmlEscape(category), '</p>',
    '<p><strong>Section:</strong> ', htmltools::htmlEscape(section), '</p>',
    '<p><strong>Feedback:</strong></p>',
    '<blockquote style="border-left:3px solid #003366;padding:8px 12px;margin:8px 0;background:#f9f9f9;">',
    htmltools::htmlEscape(text), '</blockquote></div>'
  )

  fb_email  <- blastula::compose_email(body = blastula::md(body_html))
  fb_result <- tryCatch({
    blastula::smtp_send(
      email       = fb_email,
      to          = "acastleman@uu.edu",
      from        = Sys.getenv("SMTP_USER"),
      cc          = student_email,
      subject     = sprintf("Tutorial Feedback \u2014 TUTORIAL_SHORT_NAME \u2014 %s \u2014 %s",
                            category, format(now, "%Y-%m-%d")),
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
    output$feedback_status <- renderUI(
      tags$div(
        style = "background:#d4edda;border:1px solid #c3e6cb;padding:12px 15px;border-radius:5px;margin-top:12px;",
        tags$p(style = "color:#155724;margin:0;", "\u2713 Feedback sent \u2014 thank you!")
      )
    )
  } else {
    output$feedback_status <- renderUI(
      tags$div(
        style = "background:#f8d7da;border:1px solid #f5c6cb;padding:12px 15px;border-radius:5px;margin-top:12px;",
        tags$p(style = "color:#721c24;margin:0;",
               paste("Feedback could not be sent \u2014 please email Dr. Castleman directly.", fb_result))
      )
    )
  }
})

# Confidence calibration logging
# Update the IDs to match your content sections (e.g., confidence_sf, confidence_sb, ...)
lapply(c("confidence_s1", "confidence_s2", "confidence_s3"), function(id) {
  observeEvent(input[[id]], {
    tryCatch({
      googlesheets4::sheet_append(
        Sys.getenv("GS4_SHEET_ID"),
        data.frame(
          user                  = session_user,
          app                   = TUTORIAL_ID,
          date                  = format(Sys.time(), "%Y-%m-%d"),
          time                  = format(Sys.time(), "%H:%M:%S"),
          question              = id,
          attempt               = 1L,
          first_attempt_correct = NA,
          correct               = NA,
          answer_text           = input[[id]]
        ),
        sheet = "question_events"
      )
    }, error = function(e) message("Confidence log failed: ", e$message))
  })
})

# Student-generated MCQ submission
output$student_q_status <- renderUI(NULL)

observeEvent(input$submit_student_q, {
  stem        <- trimws(input$student_q_stem)
  correct_ans <- input$student_q_correct

  if (nchar(stem) == 0 || identical(correct_ans, "")) {
    output$student_q_status <- renderUI(
      tags$p(style = "color:#721c24; margin-top:8px;",
             "Please write a question stem and select the correct answer.")
    )
    return()
  }

  now        <- Sys.time()
  student_id <- if (!is.null(session$user) && nzchar(session$user)) session$user else "unknown"

  body_html <- paste0(
    '<div style="font-family:Arial,Helvetica,sans-serif;max-width:680px;color:#222;">',
    '<h2 style="color:#003366;border-bottom:2px solid #003366;padding-bottom:6px;">',
    'Student-Generated MCQ \u2014 TUTORIAL_NAME</h2>',
    '<p><strong>Student:</strong> ', htmltools::htmlEscape(student_id), '</p>',
    '<p><strong>Submitted:</strong> ', format(now, "%Y-%m-%d %H:%M:%S"), '</p>',
    '<p><strong>Question:</strong></p>',
    '<blockquote style="border-left:3px solid #003366;padding:8px 12px;margin:8px 0;background:#f9f9f9;">',
    htmltools::htmlEscape(stem), '</blockquote>',
    '<p>A) ', htmltools::htmlEscape(input$student_q_a), '</p>',
    '<p>B) ', htmltools::htmlEscape(input$student_q_b), '</p>',
    '<p>C) ', htmltools::htmlEscape(input$student_q_c), '</p>',
    '<p>D) ', htmltools::htmlEscape(input$student_q_d), '</p>',
    '<p><strong>Correct answer:</strong> ', htmltools::htmlEscape(correct_ans), '</p>',
    '<p><strong>Explanation:</strong></p>',
    '<blockquote style="border-left:3px solid #2d6a4f;padding:8px 12px;margin:8px 0;background:#f0f8f0;">',
    htmltools::htmlEscape(input$student_q_explanation), '</blockquote>',
    '</div>'
  )

  mcq_email  <- blastula::compose_email(body = blastula::md(body_html))
  mcq_result <- tryCatch({
    blastula::smtp_send(
      email       = mcq_email,
      to          = "acastleman@uu.edu",
      from        = Sys.getenv("SMTP_USER"),
      subject     = sprintf("Student MCQ \u2014 TUTORIAL_SHORT_NAME \u2014 %s \u2014 %s",
                            htmltools::htmlEscape(student_id), format(now, "%Y-%m-%d")),
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

  if (identical(mcq_result, "success")) {
    output$student_q_status <- renderUI(
      tags$div(
        style = "background:#d4edda;border:1px solid #c3e6cb;padding:12px 15px;border-radius:5px;margin-top:12px;",
        tags$p(style = "color:#155724;margin:0;", "\u2713 Question submitted \u2014 thank you!")
      )
    )
  } else {
    output$student_q_status <- renderUI(
      tags$div(
        style = "background:#f8d7da;border:1px solid #f5c6cb;padding:12px 15px;border-radius:5px;margin-top:12px;",
        tags$p(style = "color:#721c24;margin:0;",
               paste("Could not send \u2014 please try again.", mcq_result))
      )
    )
  }
})
```
```

---

## JavaScript — Section Navigation

Place this block immediately before the first `##` section heading in the Rmd (after the server chunks).

```html
<script>
$(document).ready(function () {
  function recordSection() {
    var hash = window.location.hash;
    if (hash && typeof Shiny !== "undefined" && Shiny.setInputValue) {
      Shiny.setInputValue("learnr_section", {
        section:   hash.replace(/^#/, ""),
        timestamp: new Date().toISOString()
      }, { priority: "event" });
    }
  }
  if (window.location.hash) recordSection();
  $(window).on("hashchange", recordSection);
});
</script>
```

---

## Feedback Form UI

Place in the **Welcome & Study Plan** section. Update `choices` in `feedback_section` to match your actual section names (include all sections plus "General").

```r
```{r welcome-feedback-ui, echo=FALSE}
fluidRow(
  column(8,
    selectInput("feedback_category", "Category:",
      choices = c("Select a category...",
                  "Factual error",
                  "Level mismatch",
                  "Conceptual gap",
                  "Clarity issue",
                  "Question design",
                  "Positive",
                  "Other"),
      selected = "Select a category..."
    ),
    selectInput("feedback_section", "Section:",
      choices = c("Welcome & Study Plan", "Primer", "Immediate Review",
                  "Section 1 Name", "Section 2 Name",
                  "Synthesis", "Model Summary", "What's Next", "General")
    ),
    textAreaInput("feedback_text", "Your feedback:", rows = 4,
      placeholder = "e.g. 'The explanation of X in Section 1 was confusing — I wasn't sure if it meant Y or Z'"),
    actionButton("submit_feedback", "Send Feedback",
      style = "background:#003366;color:white;border:none;padding:8px 20px;"),
    uiOutput("feedback_status")
  )
)
```
```

---

## Question Submission UI

Place in the **Welcome & Study Plan** section, below the feedback form.

```r
```{r welcome-question-ui, echo=FALSE}
fluidRow(
  column(8,
    textAreaInput("student_question", "Your question:",
      rows = 3,
      placeholder = "Ask anything about this topic — no question is too basic"),
    actionButton("submit_question", "Send Question",
      style = "background:#003366;color:white;border:none;padding:8px 20px;"),
    uiOutput("question_status")
  )
)
```
```

---

## Confidence Calibration UI

Place one `radioButtons` at the end of each content section (before the `---` separator). Update the ID suffix and question text for each section.

```r
```{r confidence-s1, echo=FALSE}
radioButtons("confidence_s1",
  "Before moving on: how confident are you that you could answer exam questions about [section topic summary]?",
  choices = c("1 — Not at all" = "1", "2 — Slightly" = "2",
              "3 — Moderately" = "3", "4 — Very" = "4",
              "5 — Completely" = "5"),
  selected = character(0), inline = TRUE)
```
```

The server-side logging for these is handled by the `lapply(...)` block in the server chunk — just make sure the IDs in `lapply()` match the IDs used in the UI.

---

## Student-Generated MCQ UI

Place in the **Synthesis** section, after the interleaved practice questions.

```r
```{r student-mcq-ui, echo=FALSE}
fluidRow(
  column(8,
    textAreaInput("student_q_stem", "Question stem:", rows = 3,
      placeholder = "Write a question about this tutorial's content..."),
    textInput("student_q_a", "Option A:"),
    textInput("student_q_b", "Option B:"),
    textInput("student_q_c", "Option C:"),
    textInput("student_q_d", "Option D:"),
    selectInput("student_q_correct", "Correct answer:",
      choices = c("Select..." = "", "A", "B", "C", "D")),
    textAreaInput("student_q_explanation", "Why is this the correct answer?", rows = 3,
      placeholder = "Explain the reasoning — what misconception does each wrong answer represent?"),
    actionButton("submit_student_q", "Submit Question",
      style = "background:#003366;color:white;border:none;padding:8px 20px;"),
    uiOutput("student_q_status")
  )
)
```
```

---

## Gotchas

- **`tutorial.event_recorder` not `event_register_handler`** — the handler version does not reliably fire for question events in learnr 0.10.x/0.11.x on shinyapps.io. Always use `options(tutorial.event_recorder = ...)`.
- **`user_id` is `'shiny'` on shinyapps.io** — always pull the authenticated user from `shiny::getDefaultReactiveDomain()$user`, with fallback to `user_id`.
- **Case-sensitive `"unknown"`** — use lowercase `"unknown"` consistently in both `session_user` assignment and all comparisons (e.g., `!identical(student_id, "unknown")`). Capital-U `"Unknown"` causes the CC email logic to generate `unknown@my.uu.edu` addresses.
- **XSS prevention** — always wrap user-supplied text in `htmltools::htmlEscape()` before embedding in HTML email bodies. This applies to feedback text, student questions, and MCQ submissions.
- **Attempt counter resets per day** — the key includes `format(Sys.Date(), "%Y%m%d")`, so counts reset at midnight.
- **New Google Sheets must be shared with the service account** — the `client_email` from the service account JSON must be added as Editor before the first write.
- **`sheet = "sessions"` argument required** — `log_session()` must pass the named tab, not the default Sheet1.
- **Confidence calibration IDs must match** — the IDs in the `lapply()` server block must exactly match the `radioButtons()` IDs in the UI chunks.
