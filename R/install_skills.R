#' Install Claude Code skills from the package
#'
#' Copies the skill files bundled in this package to the local `.claude/skills/`
#' directory, making them available to Claude Code for tutorial creation.
#'
#' @param target Directory to install skills into. Defaults to `.claude/skills/`
#'   in the current working directory. Set to a user-level path
#'   (e.g., `"~/.claude/skills/"`) for global installation.
#' @param overwrite Logical. If `TRUE`, overwrite existing skill files.
#'   Defaults to `TRUE` to ensure latest versions.
#'
#' @return Invisible character vector of installed skill paths.
#' @export
install_skills <- function(target = file.path(".", ".claude", "skills"),
                           overwrite = TRUE) {
  src <- system.file("claude-skills", package = "uucopTutorials", mustWork = FALSE)

  if (!nzchar(src) || !dir.exists(src)) {
    message("No bundled skills found in the uucopTutorials package.")
    return(invisible(character(0)))
  }

  skill_dirs <- list.dirs(src, full.names = TRUE, recursive = FALSE)
  installed  <- character(0)

  for (skill_dir in skill_dirs) {
    skill_name <- basename(skill_dir)
    dest_dir   <- file.path(target, skill_name)
    dir.create(dest_dir, showWarnings = FALSE, recursive = TRUE)

    files <- list.files(skill_dir, full.names = TRUE, recursive = TRUE)
    for (f in files) {
      rel  <- sub(paste0("^", normalizePath(skill_dir, winslash = "/"), "/?"), "",
                  normalizePath(f, winslash = "/"))
      dest <- file.path(dest_dir, rel)
      dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
      file.copy(f, dest, overwrite = overwrite)
    }

    installed <- c(installed, dest_dir)
    message("  Installed skill: ", skill_name, " -> ", dest_dir)
  }

  message("Skills installation complete. ", length(installed), " skill(s) installed.")
  invisible(installed)
}
