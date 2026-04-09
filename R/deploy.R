#' Create a deployment configuration for a course
#'
#' Returns a list of helper functions (`deploy_tutorial`, `inject_credentials`,
#' `setup_sheets`, `invite_students`, `show_users`, `remove_students`) configured
#' for a specific course. Source this in a course-level `deploy.R` script.
#'
#' @param account shinyapps.io account name. Defaults to `"uucop"`.
#' @param server Deployment server. Defaults to `"shinyapps.io"`.
#' @param sheet_id Google Sheet ID for this course.
#' @param repo_root Path to the course repo root.
#' @param secrets_dir Path to the `.secrets/` directory containing the service
#'   account JSON. Defaults to `file.path(repo_root, "..", ".secrets")`.
#' @param tutorials Named list of tutorial configurations. Each element should be
#'   a list with `name` (shinyapps.io app name) and `file` (path to Rmd relative
#'   to `repo_root`).
#' @param smtp_user SMTP username for feedback emails.
#' @param smtp_pass SMTP password (app password) for feedback emails.
#'
#' @return A list of functions: `deploy_tutorial`, `inject_credentials`,
#'   `setup_sheets`, `invite_students`, `show_users`, `remove_students`.
#' @export
setup_deploy <- function(account    = "uucop",
                         server     = "shinyapps.io",
                         sheet_id,
                         repo_root,
                         secrets_dir = NULL,
                         tutorials,
                         smtp_user  = "uucop.shinyapps@gmail.com",
                         smtp_pass  = NULL) {

  if (is.null(secrets_dir)) {
    rel_path    <- normalizePath(file.path(repo_root, "..", ".secrets"), mustWork = FALSE)
    global_path <- normalizePath("C:/uucop/.secrets", mustWork = FALSE)
    secrets_dir <- if (dir.exists(rel_path)) rel_path else global_path
  }
  gs4_json <- file.path(secrets_dir, "gs4-service-account.json")

  # -- inject_credentials -------------------------------------------------------
  inject_credentials <- function(tutorial_keys = names(tutorials)) {
    if (!file.exists(gs4_json)) stop("GS4 JSON not found: ", gs4_json)

    for (key in tutorial_keys) {
      cfg <- tutorials[[key]]
      if (is.null(cfg)) { message("Unknown tutorial: ", key); next }

      tut_dir <- file.path(repo_root, dirname(cfg$file))
      sec_dir <- file.path(tut_dir, "secrets")
      dir.create(sec_dir, showWarnings = FALSE, recursive = TRUE)
      file.copy(gs4_json, file.path(sec_dir, "gs4-service-account.json"), overwrite = TRUE)

      env_path <- file.path(tut_dir, ".Renviron")
      existing <- if (file.exists(env_path)) readLines(env_path, warn = FALSE) else character(0)
      existing <- existing[!grepl("^GS4_|^SMTP_", existing)]

      env_lines <- c(existing, paste0("GS4_SHEET_ID=", sheet_id))
      if (nzchar(smtp_user)) env_lines <- c(env_lines, paste0("SMTP_USER=", smtp_user))
      if (!is.null(smtp_pass) && nzchar(smtp_pass)) {
        env_lines <- c(env_lines, paste0("SMTP_PASS=", smtp_pass))
      }
      writeLines(env_lines, env_path)

      message("  Credentials injected: ", key, " (", tut_dir, ")")
    }
  }

  # -- deploy_tutorial ----------------------------------------------------------
  deploy_tutorial <- function(tutorial_keys = names(tutorials)) {
    message("Injecting credentials...")
    inject_credentials(tutorial_keys)

    for (key in tutorial_keys) {
      cfg <- tutorials[[key]]
      if (is.null(cfg)) { message("Unknown tutorial: ", key); next }

      doc_path <- file.path(repo_root, cfg$file)
      if (!file.exists(doc_path)) {
        message("  SKIP ", key, " \u2014 file not found: ", doc_path)
        next
      }

      message("\n\u2500\u2500 Deploying ", cfg$name, " \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500")
      tryCatch(
        rsconnect::deployDoc(
          doc     = doc_path,
          appName = cfg$name,
          account = account,
          server  = server,
          forceUpdate    = TRUE,
          launch.browser = FALSE
        ),
        error = function(e) message("  ERROR: ", e$message)
      )
    }
    message("\nDeployment complete.")
  }

  # -- setup_sheets -------------------------------------------------------------
  setup_sheets <- function() {
    if (!file.exists(gs4_json)) stop("GS4 JSON not found: ", gs4_json)
    googlesheets4::gs4_auth(path = gs4_json)
    setup_tracking_sheets(sheet_id)
  }

  # -- read_students (internal) -------------------------------------------------
  read_students <- function(csv_path) {
    if (!file.exists(csv_path)) stop("Student CSV not found: ", csv_path)
    df <- read.csv(csv_path, stringsAsFactors = FALSE)
    names(df) <- tolower(names(df))
    if (!"email" %in% names(df)) stop("CSV must contain an 'email' column.")
    emails <- trimws(df$email)
    emails <- emails[nzchar(emails)]
    message("Loaded ", length(emails), " emails from ", csv_path)
    emails
  }

  # -- invite_students ----------------------------------------------------------
  invite_students <- function(csv_path, tutorial_keys = names(tutorials),
                              send_email = TRUE, message_text = NULL) {
    emails <- read_students(csv_path)

    for (key in tutorial_keys) {
      cfg <- tutorials[[key]]
      if (is.null(cfg)) { message("Unknown tutorial: ", key); next }

      message("\n\u2500\u2500 Inviting to ", cfg$name, " \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500")
      results <- lapply(emails, function(email) {
        tryCatch({
          rsconnect::addAuthorizedUser(
            email        = email,
            appName      = cfg$name,
            account      = account,
            server       = server,
            sendEmail    = send_email,
            emailMessage = message_text
          )
          message("  OK  ", email)
          list(email = email, status = "ok")
        }, error = function(e) {
          message("  SKIP ", email, " \u2014 ", e$message)
          list(email = email, status = "error", message = e$message)
        })
      })

      n_ok  <- sum(vapply(results, \(r) r$status == "ok", logical(1)))
      n_err <- sum(vapply(results, \(r) r$status == "error", logical(1)))
      message("  Done: ", n_ok, " invited, ", n_err, " skipped/failed")
    }
  }

  # -- show_users ---------------------------------------------------------------
  show_users <- function(tutorial_keys = names(tutorials)) {
    for (key in tutorial_keys) {
      cfg <- tutorials[[key]]
      if (is.null(cfg)) { message("Unknown tutorial: ", key); next }
      message("\n\u2500\u2500 Authorized users: ", cfg$name, " \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500")
      tryCatch({
        users <- rsconnect::showUsers(appName = cfg$name, account = account, server = server)
        print(users)
      }, error = function(e) message("  Could not retrieve users: ", e$message))
    }
  }

  # -- remove_students ----------------------------------------------------------
  remove_students <- function(csv_path, tutorial_keys = names(tutorials)) {
    emails <- read_students(csv_path)

    for (key in tutorial_keys) {
      cfg <- tutorials[[key]]
      if (is.null(cfg)) { message("Unknown tutorial: ", key); next }

      message("\n\u2500\u2500 Removing from ", cfg$name, " \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500")
      lapply(emails, function(email) {
        tryCatch({
          rsconnect::removeAuthorizedUser(
            email   = email,
            appName = cfg$name,
            account = account,
            server  = server
          )
          message("  Removed ", email)
        }, error = function(e) message("  SKIP ", email, " \u2014 ", e$message))
      })
    }
  }

  list(
    deploy_tutorial    = deploy_tutorial,
    inject_credentials = inject_credentials,
    setup_sheets       = setup_sheets,
    invite_students    = invite_students,
    show_users         = show_users,
    remove_students    = remove_students
  )
}
