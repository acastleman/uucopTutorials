#' Build the HTML body for a prelab submission email
#'
#' Generates an inline-styled HTML email containing a summary stats box and a
#' color-coded quiz response table. The output is passed directly to
#' [send_prelab_email()].
#'
#' @param q_entries Named list of question entries from
#'   `learnr::get_tutorial_state()`. Each element should have `$answer` and
#'   `$correct` fields.
#' @param total_questions Integer. Total number of questions in this prelab
#'   (including free-text questions). Update this constant when questions are
#'   added or removed.
#' @param text_q_ids Character vector of chunk labels for `question_text()`
#'   items. These are excluded from the score denominator.
#' @param q_labels Named character vector mapping question IDs (chunk labels)
#'   to human-readable descriptions shown in the email table.
#' @param student_id Authenticated username string.
#' @param elapsed_min Numeric. Minutes elapsed since session start.
#' @param prelab_title Character string used in the email heading (e.g.,
#'   `"Prelab 1"`).
#'
#' @return Character string containing the complete HTML body.
#' @export
build_prelab_email_html <- function(q_entries,
                                     total_questions,
                                     text_q_ids,
                                     q_labels,
                                     student_id,
                                     elapsed_min,
                                     prelab_title) {
  # --- Score calculation ---
  n_attempted      <- length(q_entries)
  pct_attempted    <- round(n_attempted / total_questions * 100, 1)
  non_text         <- q_entries[!names(q_entries) %in% text_q_ids]
  n_non_text_total <- total_questions - length(text_q_ids)
  n_correct        <- sum(vapply(non_text, function(x) isTRUE(x$correct), logical(1)))
  pct_correct      <- round(n_correct / n_non_text_total * 100, 1)
  score_label      <- paste0(n_correct, " / ", n_non_text_total, " (", pct_correct, "%)")

  # --- Summary box ---
  summary_html <- paste0(
    '<div style="background:#f0f4f8;border-left:4px solid #003366;padding:12px 16px;',
    'margin-bottom:20px;border-radius:3px;font-family:Arial,Helvetica,sans-serif;">',
    '<p style="margin:4px 0;font-size:14px;"><strong>Questions attempted:</strong> ',
    n_attempted, ' / ', total_questions, ' (', pct_attempted, '%)</p>',
    '<p style="margin:4px 0;font-size:14px;"><strong>Score (graded questions only):</strong> ',
    score_label, '</p>',
    '</div>'
  )

  # --- Response table ---
  if (length(q_entries) > 0) {
    rows <- vapply(names(q_entries), function(id) {
      e      <- q_entries[[id]]
      label  <- if (!is.null(q_labels[id]) && !is.na(q_labels[id])) q_labels[[id]] else id
      ans    <- paste(e$answer, collapse = "; ")
      bg     <- if (isTRUE(e$correct)) "#d4edda" else if (identical(e$correct, FALSE)) "#f8d7da" else "#fff8e1"
      symbol <- if (isTRUE(e$correct)) "&#10003;" else if (identical(e$correct, FALSE)) "&#10007;" else "&#63;"
      sprintf(
        paste0('<tr style="background:%s;">',
               '<td style="padding:6px 10px;border:1px solid #ccc;font-size:13px;">%s</td>',
               '<td style="padding:6px 10px;border:1px solid #ccc;font-size:13px;">%s</td>',
               '<td style="padding:6px 10px;border:1px solid #ccc;text-align:center;font-size:13px;">%s</td>',
               '</tr>'),
        bg, label, ans, symbol
      )
    }, character(1))

    table_html <- paste0(
      '<table style="border-collapse:collapse;width:100%;">',
      '<tr>',
      '<th style="background:#003366;color:white;padding:8px 10px;border:1px solid #ccc;text-align:left;">Question</th>',
      '<th style="background:#003366;color:white;padding:8px 10px;border:1px solid #ccc;text-align:left;">Answer</th>',
      '<th style="background:#003366;color:white;padding:8px 10px;border:1px solid #ccc;text-align:center;width:70px;">Correct</th>',
      '</tr>',
      paste(rows, collapse = "\n"),
      '</table>'
    )
  } else {
    table_html <- "<p><em>No quiz answers recorded.</em></p>"
  }

  # --- Full email body ---
  paste0(
    '<div style="font-family:Arial,Helvetica,sans-serif;max-width:680px;color:#222;">',
    '<h2 style="color:#003366;border-bottom:2px solid #003366;padding-bottom:6px;">',
    htmltools::htmlEscape(prelab_title), ' Submission</h2>',
    '<p><strong>Student:</strong> ', htmltools::htmlEscape(student_id), '</p>',
    '<p><strong>Submitted:</strong> ', format(Sys.time(), "%Y-%m-%d %H:%M:%S"), '</p>',
    '<p><strong>Time on task:</strong> ', round(elapsed_min, 1), ' min</p>',
    summary_html,
    '<h3 style="color:#003366;">Quiz Responses</h3>',
    table_html,
    '</div>'
  )
}

#' Send a prelab submission email
#'
#' Sends the HTML body produced by [build_prelab_email_html()] via Gmail SMTP.
#' Always CCs the lab coordinator (`raddo@uu.edu`) and, if known, the student.
#'
#' @param html_body Character string from [build_prelab_email_html()].
#' @param student_id Authenticated username string (used in subject line).
#' @param student_email Character vector from [derive_student_email()].
#'   Use `character(0)` if the student is unknown.
#' @param prelab_title Character string used in the subject line (e.g.,
#'   `"Prelab 1"`).
#' @param to Instructor email address. Defaults to `"acastleman@uu.edu"`.
#' @param cc_always Character vector of addresses always CC'd regardless of
#'   student identity. Defaults to `"raddo@uu.edu"` (lab coordinator).
#'
#' @return `"success"` if sent, or the error message string if sending failed.
#' @export
send_prelab_email <- function(html_body,
                               student_id,
                               student_email,
                               prelab_title,
                               to        = "acastleman@uu.edu",
                               cc_always = "raddo@uu.edu") {
  cc      <- c(cc_always, student_email)
  subject <- sprintf("%s \u2014 %s \u2014 %s",
                     prelab_title, student_id, format(Sys.time(), "%Y-%m-%d"))
  smtp_send_html(html_body, to = to, subject = subject, cc = cc)
}
