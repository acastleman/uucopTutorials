#' Derive a student's email address from their session username
#'
#' Shinyapps.io provides the authenticated username via `session$user`. This
#' helper appends the institutional domain if no `@` is present, and returns
#' `character(0)` (no CC) if the user is unknown.
#'
#' @param session_user Character string from `session$user` (or a resolved
#'   fallback such as `"unknown"`).
#' @param unknown The sentinel value used for unauthenticated sessions.
#'   Defaults to `"unknown"`.
#' @param domain Domain to append when `session_user` contains no `@`.
#'   Defaults to `"my.uu.edu"`.
#'
#' @return Character vector of length 1 (the email address), or `character(0)`
#'   if the user is unknown.
#' @export
derive_student_email <- function(session_user,
                                  unknown = "unknown",
                                  domain  = "my.uu.edu") {
  if (identical(session_user, unknown) || !nzchar(session_user)) {
    return(character(0))
  }
  if (grepl("@", session_user)) session_user else paste0(session_user, "@", domain)
}

#' Render a success or failure status box for email submission
#'
#' Returns a `tags$div` suitable for wrapping in [shiny::renderUI()]. Used
#' after any submit action (feedback, question, prelab submission) to display
#' a green success banner or a red failure banner.
#'
#' @param success Logical. `TRUE` for success, `FALSE` for failure.
#' @param success_msg Message displayed on success. Defaults to a generic
#'   confirmation.
#' @param error_detail Character string appended to the failure message
#'   (typically the error condition message). Defaults to `""`.
#' @param fail_prefix Introductory phrase for failure messages. Defaults to
#'   `"Could not send \u2014 please email the instructor directly."`.
#'
#' @return A [shiny::tags] object.
#' @export
render_send_status <- function(success,
                                success_msg  = "\u2713 Sent successfully \u2014 thank you!",
                                error_detail = "",
                                fail_prefix  = "Could not send \u2014 please email the instructor directly.") {
  if (success) {
    shiny::tags$div(
      style = "background:#d4edda;border:1px solid #c3e6cb;padding:12px 15px;border-radius:5px;margin-top:12px;",
      shiny::tags$p(style = "color:#155724;margin:0;", success_msg)
    )
  } else {
    msg <- if (nzchar(trimws(error_detail))) {
      paste(fail_prefix, error_detail)
    } else {
      fail_prefix
    }
    shiny::tags$div(
      style = "background:#f8d7da;border:1px solid #f5c6cb;padding:12px 15px;border-radius:5px;margin-top:12px;",
      shiny::tags$p(style = "color:#721c24;margin:0;", msg)
    )
  }
}

#' Send an HTML email via Gmail SMTP using environment credentials
#'
#' Internal wrapper around [blastula::smtp_send()]. Reads `SMTP_USER` and
#' `SMTP_PASS` from the environment. Always uses Gmail on port 465 with SSL.
#'
#' @param html_body Character string containing the full HTML email body.
#' @param to Recipient email address(es).
#' @param subject Email subject line.
#' @param cc Character vector of CC addresses. Defaults to `character(0)`.
#'
#' @return `"success"` if sent, or the error message string if sending failed.
#' @keywords internal
smtp_send_html <- function(html_body, to, subject, cc = character(0)) {
  email_obj <- blastula::compose_email(body = blastula::md(html_body))
  tryCatch({
    blastula::smtp_send(
      email       = email_obj,
      to          = to,
      from        = Sys.getenv("SMTP_USER"),
      cc          = cc,
      subject     = subject,
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
}
