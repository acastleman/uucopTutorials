#' Standard local root for UUCOP working environment
#'
#' Returns `"C:/uucop"` on Windows and `"~/uucop"` (expanded) on macOS/Linux.
#' Used as the default `local_root` in [setup_environment()] and as the
#' credential fallback location in [setup_deploy()].
#'
#' @return Character string — absolute path to the local root.
#' @export
uucop_local_root <- function() {
  if (.Platform$OS.type == "windows") "C:/uucop" else path.expand("~/uucop")
}

#' Set up a local UUCOP working environment
#'
#' Creates the standard local working directory, copies credentials from a
#' shared location, configures the rsconnect account, writes SMTP credentials
#' to `~/.Renviron`, and optionally installs Claude Code skills globally.
#' Intended for Tier 2+ onboarding — run once per machine.
#'
#' @param shared_drive_path Path to the shared drive folder containing the
#'   credentials files (`gs4-service-account.json`, `rsconnect.dcf`,
#'   `smtp-credentials.txt`).
#' @param local_root Root of the local working directory. Defaults to
#'   `"C:/uucop"` on Windows and `"~/uucop"` on macOS/Linux via
#'   [uucop_local_root()].
#' @param install_skills_global Logical. If `TRUE` (default), installs bundled
#'   Claude Code skills to `~/.claude/skills/` so they are available globally.
#'
#' @details
#' **Expected files in `shared_drive_path`:**
#' \describe{
#'   \item{`gs4-service-account.json`}{Google service account key for Sheets logging.}
#'   \item{`rsconnect.dcf`}{shinyapps.io credentials in DCF format: fields
#'     `name`, `token`, `secret`.}
#'   \item{`smtp-credentials.txt`}{SMTP credentials, one per line:
#'     `SMTP_USER=...` and `SMTP_PASS=...`.}
#' }
#'
#' **Directory structure created under `local_root`:**
#' \preformatted{
#' uucop/               (C:/uucop on Windows; ~/uucop on macOS)
#'   .secrets/    <- credentials copied here
#'   courses/     <- clone course repos here
#'   hub/         <- clone uucop-hub here
#'   package/     <- clone uucopTutorials here
#' }
#'
#' After running, restart R to activate SMTP credentials written to
#' `~/.Renviron`.
#'
#' @return Invisible path to `local_root`.
#' @export
setup_environment <- function(shared_drive_path,
                              local_root            = uucop_local_root(),
                              install_skills_global = TRUE) {

  shared_drive_path <- normalizePath(shared_drive_path, mustWork = FALSE)
  local_root        <- normalizePath(local_root,        mustWork = FALSE)

  # ── 1. Create directory structure ──────────────────────────────────────────
  dirs <- c(
    local_root,
    file.path(local_root, ".secrets"),
    file.path(local_root, "courses"),
    file.path(local_root, "hub"),
    file.path(local_root, "package")
  )
  for (d in dirs) dir.create(d, showWarnings = FALSE, recursive = TRUE)
  message("Directory structure created at: ", local_root)

  # ── 2. Copy credentials from shared drive ──────────────────────────────────
  secrets_dst <- file.path(local_root, ".secrets")
  cred_files  <- c(
    "gs4-service-account.json",
    "rsconnect.dcf",
    "smtp-credentials.txt"
  )
  for (f in cred_files) {
    src <- file.path(shared_drive_path, f)
    if (file.exists(src)) {
      file.copy(src, file.path(secrets_dst, f), overwrite = TRUE)
      message("  Copied: ", f)
    } else {
      message("  MISSING: ", f, " (not found in shared drive — skipping)")
    }
  }

  # ── 3. Configure rsconnect account ─────────────────────────────────────────
  dcf_path <- file.path(secrets_dst, "rsconnect.dcf")
  if (file.exists(dcf_path)) {
    creds <- tryCatch(read.dcf(dcf_path)[1L, ], error = function(e) NULL)
    if (!is.null(creds) && all(c("name", "token", "secret") %in% names(creds))) {
      rsconnect::setAccountInfo(
        name   = creds[["name"]],
        token  = creds[["token"]],
        secret = creds[["secret"]]
      )
      message("  rsconnect account configured: ", creds[["name"]], " @ shinyapps.io")
    } else {
      message("  rsconnect.dcf found but malformed — check name/token/secret fields")
    }
  } else {
    message("  SKIP rsconnect setup — rsconnect.dcf not found")
  }

  # ── 4. Write SMTP credentials to ~/.Renviron ───────────────────────────────
  smtp_path <- file.path(secrets_dst, "smtp-credentials.txt")
  if (file.exists(smtp_path)) {
    smtp_lines <- readLines(smtp_path, warn = FALSE)
    smtp_lines <- smtp_lines[nzchar(trimws(smtp_lines)) & !grepl("^#", smtp_lines)]
    renviron_path <- path.expand("~/.Renviron")
    existing <- if (file.exists(renviron_path)) readLines(renviron_path, warn = FALSE) else character(0)
    existing <- existing[!grepl("^SMTP_", existing)]
    writeLines(c(existing, smtp_lines), renviron_path)
    message("  SMTP credentials written to ~/.Renviron")
  } else {
    message("  SKIP SMTP setup — smtp-credentials.txt not found")
  }

  # ── 5. Install Claude Code skills globally ─────────────────────────────────
  if (install_skills_global) {
    skills_target <- path.expand(file.path("~", ".claude", "skills"))
    install_skills(target = skills_target)
  }

  # ── 6. Next steps ──────────────────────────────────────────────────────────
  courses_dir <- file.path(local_root, "courses")
  pkg_dir     <- file.path(local_root, "package")
  hub_dir     <- file.path(local_root, "hub")

  message(
    "\n== Setup complete ==\n",
    "Next steps:\n",
    "  1. Restart R to activate SMTP credentials\n",
    "  2. Clone course repos into ", courses_dir, "/\n",
    "       git clone https://github.com/acastleman/Pharmacokinetics.git ",
    file.path(courses_dir, "pk"), "\n",
    "       git clone https://github.com/acastleman/NonsterileCompounding.git ",
    file.path(courses_dir, "nonsterile"), "\n",
    "       (repeat for other courses — see uucop-hub README)\n",
    "  3. Clone the package:\n",
    "       git clone https://github.com/acastleman/uucopTutorials.git ",
    file.path(pkg_dir, "uucopTutorials"), "\n",
    "  4. Clone the hub:\n",
    "       git clone https://github.com/acastleman/uucop-hub.git ",
    file.path(hub_dir, "uucop-hub"), "\n",
    "  5. Install the package:\n",
    "       devtools::install_github('acastleman/uucopTutorials')\n"
  )

  invisible(local_root)
}
