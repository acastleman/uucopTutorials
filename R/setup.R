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
#' Reads credentials from `<local_root>/.secrets/`, configures the rsconnect
#' account, writes SMTP credentials to `~/.Renviron`, installs required
#' packages, and optionally installs Claude Code skills globally. Intended for
#' Tier 2+ onboarding — run once per machine.
#'
#' @details
#' **Before running:** copy the shared `secrets` folder into your local root
#' (Windows: `C:/uucop/`; macOS: `~/uucop/`) and rename it `.secrets`.
#'
#' **Expected files in `.secrets/`:**
#' \describe{
#'   \item{`gs4-service-account.json`}{Google service account key for Sheets logging.}
#'   \item{`rsconnect.dcf`}{shinyapps.io credentials — fields: `name`, `token`, `secret`.}
#'   \item{`smtp-credentials.txt`}{One line each: `SMTP_USER=...` and `SMTP_PASS=...`.}
#' }
#'
#' **Directory structure expected under `local_root`:**
#' \preformatted{
#' uucop/               (C:/uucop on Windows; ~/uucop on macOS)
#'   .secrets/    <- copy and rename the shared 'secrets' folder here
#'   courses/     <- clone course repos here
#'   hub/         <- clone uucop-hub here
#'   package/     <- clone uucopTutorials here
#' }
#'
#' After running, restart R to activate SMTP credentials written to
#' `~/.Renviron`.
#'
#' @param local_root Root of the local working directory. Defaults to
#'   `"C:/uucop"` on Windows and `"~/uucop"` on macOS/Linux via
#'   [uucop_local_root()]. Should already contain a `.secrets/` subfolder.
#' @param install_skills_global Logical. If `TRUE` (default), installs bundled
#'   Claude Code skills to `~/.claude/skills/` so they are available globally.
#'
#' @return Invisible path to `local_root`.
#' @export
setup_environment <- function(local_root            = uucop_local_root(),
                              install_skills_global = TRUE) {

  local_root <- normalizePath(local_root, mustWork = FALSE)

  # ── 0. Rename secrets → .secrets if needed ────────────────────────────────
  secrets_visible <- file.path(local_root, "secrets")
  secrets_hidden  <- file.path(local_root, ".secrets")
  if (!dir.exists(secrets_hidden) && dir.exists(secrets_visible)) {
    file.rename(secrets_visible, secrets_hidden)
    message("  Renamed secrets/ to .secrets/")
  }

  # ── 1. Create any missing subdirectories ───────────────────────────────────
  dirs <- c(
    local_root,
    file.path(local_root, ".secrets"),
    file.path(local_root, "courses"),
    file.path(local_root, "hub"),
    file.path(local_root, "package")
  )
  for (d in dirs) dir.create(d, showWarnings = FALSE, recursive = TRUE)
  message("Local root: ", local_root)

  secrets_dir <- file.path(local_root, ".secrets")

  # ── 2. Configure rsconnect account ─────────────────────────────────────────
  dcf_path <- file.path(secrets_dir, "rsconnect.dcf")
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
    message("  SKIP rsconnect — rsconnect.dcf not found in ", secrets_dir)
    message("    Copy and rename the shared 'secrets' folder to .secrets/ first.")
  }

  # ── 3. Write SMTP credentials to ~/.Renviron ───────────────────────────────
  smtp_path <- file.path(secrets_dir, "smtp-credentials.txt")
  if (file.exists(smtp_path)) {
    smtp_lines <- readLines(smtp_path, warn = FALSE)
    smtp_lines <- smtp_lines[nzchar(trimws(smtp_lines)) & !grepl("^#", smtp_lines)]
    renviron_path <- path.expand("~/.Renviron")
    existing <- if (file.exists(renviron_path)) readLines(renviron_path, warn = FALSE) else character(0)
    existing <- existing[!grepl("^SMTP_", existing)]
    writeLines(c(existing, smtp_lines), renviron_path)
    message("  SMTP credentials written to ~/.Renviron")
  } else {
    message("  SKIP SMTP — smtp-credentials.txt not found in ", secrets_dir)
  }

  # ── 4. Install required packages ───────────────────────────────────────────
  # All packages found across tutorials and projects in this system.
  # uucopTutorials itself is excluded (already installed to run this function).
  cran_pkgs <- c(
    "AzureAuth", "AzureGraph", "DT", "Microsoft365R",
    "RSelenium", "animation", "base64enc", "blastula", "bslib",
    "checkr", "data.table", "dplyr", "flexdashboard",
    "gargle", "gganimate", "ggplot2", "ggpubr",
    "googlesheets4", "gradethis", "grid", "gridExtra",
    "htmltools", "kableExtra", "knitr", "learnr",
    "lubridate", "magick", "magrittr", "mrgsolve",
    "officer", "pander", "plotly", "plyr",
    "png", "qwraps2", "r3dmol", "rdrop2",
    "readr", "readxl", "rmarkdown", "rsconnect",
    "rvest", "scales", "shiny", "shinyWidgets",
    "shinyTime", "shinyjs", "shinythemes", "sortable",
    "stringi", "stringr", "tidyr", "tidyverse",
    "toastui", "xlsx"
  )

  missing_pkgs <- cran_pkgs[!vapply(cran_pkgs, requireNamespace, logical(1L), quietly = TRUE)]

  if (length(missing_pkgs) == 0L) {
    message("  All packages already installed.")
  } else {
    message("  Installing ", length(missing_pkgs), " missing package(s): ",
            paste(missing_pkgs, collapse = ", "))
    tryCatch(
      install.packages(missing_pkgs, dependencies = TRUE),
      error = function(e) message("  Package install error: ", e$message)
    )
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
    "       (see uucop-hub README for full list)\n",
    "  3. Clone the package:\n",
    "       git clone https://github.com/acastleman/uucopTutorials.git ",
    file.path(pkg_dir, "uucopTutorials"), "\n",
    "  4. Clone the hub:\n",
    "       git clone https://github.com/acastleman/uucop-hub.git ",
    file.path(hub_dir, "uucop-hub"), "\n"
  )

  invisible(local_root)
}
