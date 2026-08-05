# =============================================================================
# GUID -> student identity mapping
# =============================================================================
# Posit Connect Cloud identifies a viewer only by an opaque account GUID. There
# is no server-side lookup: as of 2026-08-04 every user endpoint on the
# in-container Connect API (`/__api__/v1/user`, `/v1/me`, `/v1/users/{guid}`,
# `/v1/users`) returns 501 Not Implemented, under every auth scheme.
#
# So the mapping is maintained here. The first time a student opens ANY tutorial
# they are asked once for their school email; the GUID -> email pair is written
# to a shared `user_map` tab and reused everywhere thereafter.
#
# The map is deliberately CENTRAL (one sheet for all courses) so a student is
# asked exactly once, not once per course.
# =============================================================================

.user_map_cache <- new.env(parent = emptyenv())

#' Google Sheet ID holding the shared user map
#'
#' Reads `GS4_USER_MAP_ID`, falling back to `GS4_SHEET_ID`.
#' @return Character scalar; `""` if neither is set.
#' @export
user_map_sheet <- function() {
  id <- Sys.getenv("GS4_USER_MAP_ID")
  if (nzchar(id)) id else Sys.getenv("GS4_SHEET_ID")
}

#' Create the `user_map` tab if it does not exist
#'
#' Run once per mapping sheet, like [setup_tracking_sheets()].
#'
#' @param sheet_id Google Sheet ID. Defaults to [user_map_sheet()].
#' @return Invisible `NULL`.
#' @export
setup_user_map <- function(sheet_id = user_map_sheet()) {
  if (!nzchar(sheet_id)) stop("No user map sheet configured (GS4_USER_MAP_ID).")
  ss <- googlesheets4::gs4_get(sheet_id)
  if ("user_map" %in% googlesheets4::sheet_names(ss)) {
    message("  SKIP - tab already exists: user_map")
    return(invisible(NULL))
  }
  googlesheets4::sheet_add(ss, "user_map")
  googlesheets4::sheet_write(
    data.frame(user_guid = character(), email = character(),
               name = character(), first_seen = character(),
               stringsAsFactors = FALSE),
    ss, sheet = "user_map"
  )
  message("  Created tab: user_map")
  invisible(NULL)
}

#' Look up a viewer GUID in the user map
#'
#' Results are cached per process, so a busy tutorial reads the sheet once
#' rather than once per session.
#'
#' @param guid The viewer GUID.
#' @param sheet_id Google Sheet ID. Defaults to [user_map_sheet()].
#' @param refresh Force a re-read of the sheet, bypassing the cache.
#' @return The mapped email as a character scalar, or `NULL` if unmapped.
#' @export
user_map_lookup <- function(guid, sheet_id = user_map_sheet(), refresh = FALSE) {
  if (is.null(guid) || !nzchar(guid) || identical(guid, "unknown")) return(NULL)
  if (!refresh && !is.null(.user_map_cache[[guid]])) return(.user_map_cache[[guid]])
  if (!nzchar(sheet_id)) return(NULL)

  d <- tryCatch(
    googlesheets4::read_sheet(sheet_id, sheet = "user_map", col_types = "c"),
    error = function(e) { message("user_map read failed: ", e$message); NULL }
  )
  if (is.null(d) || !nrow(d) || !"user_guid" %in% names(d)) return(NULL)

  # Refresh the whole cache while we have the data.
  for (i in seq_len(nrow(d))) {
    g <- d$user_guid[i]
    if (!is.na(g) && nzchar(g) && !is.na(d$email[i])) .user_map_cache[[g]] <- d$email[i]
  }
  .user_map_cache[[guid]]
}

#' Record a GUID -> student mapping
#'
#' @param guid The viewer GUID.
#' @param email The student's email address.
#' @param name Optional display name.
#' @param sheet_id Google Sheet ID. Defaults to [user_map_sheet()].
#' @return Invisible `TRUE` on success, `FALSE` otherwise.
#' @export
user_map_register <- function(guid, email, name = "", sheet_id = user_map_sheet()) {
  if (is.null(guid) || !nzchar(guid) || !nzchar(email)) return(invisible(FALSE))
  ok <- tryCatch({
    googlesheets4::sheet_append(
      sheet_id,
      data.frame(user_guid = guid, email = tolower(trimws(email)),
                 name = name,
                 first_seen = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                 stringsAsFactors = FALSE),
      sheet = "user_map"
    )
    TRUE
  }, error = function(e) { message("user_map write failed: ", e$message); FALSE })
  if (ok) .user_map_cache[[guid]] <- tolower(trimws(email))
  invisible(ok)
}

#' Resolve a viewer to a student identifier, consulting the user map
#'
#' Like [uucop_user()], but on Connect Cloud it additionally translates the
#' opaque GUID into the mapped email when one is on file. Falls back to the
#' raw GUID when unmapped, so tracking still works and can be reconciled later.
#'
#' @param session A Shiny session object.
#' @param sheet_id Google Sheet ID for the map. Defaults to [user_map_sheet()].
#' @return A character scalar; never `NULL`.
#' @export
uucop_student <- function(session = shiny::getDefaultReactiveDomain(),
                          sheet_id = user_map_sheet()) {
  who <- uucop_user(session)
  if (identical(who, "unknown")) return(who)
  # A non-GUID value came from session$user and is already meaningful.
  if (!grepl("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", who)) {
    return(who)
  }
  mapped <- user_map_lookup(who, sheet_id)
  if (!is.null(mapped) && nzchar(mapped)) mapped else who
}

#' Prompt an unmapped viewer for their email, once
#'
#' Call in a `context="server"` chunk. If the viewer's GUID is already mapped,
#' or the platform supplies a real username, this does nothing.
#'
#' @param sheet_id Google Sheet ID for the map. Defaults to [user_map_sheet()].
#' @param domain Expected email domain, used for validation.
#' @param session,input,output Shiny objects.
#' @return Invisible `NULL`.
#' @export
identify_user_server <- function(sheet_id = user_map_sheet(),
                                 domain  = "my.uu.edu",
                                 session = shiny::getDefaultReactiveDomain(),
                                 input, output) {
  guid <- uucop_user(session)
  if (identical(guid, "unknown")) return(invisible(NULL))
  if (!grepl("^[0-9a-fA-F]{8}-", guid)) return(invisible(NULL))       # real username already
  if (!is.null(user_map_lookup(guid, sheet_id))) return(invisible(NULL))  # already mapped

  show_prompt <- function(msg = NULL) {
    shiny::showModal(shiny::modalDialog(
      title = "Confirm your identity",
      shiny::p("This is a one-time step so your work is recorded under your name. ",
               "You will not be asked again."),
      shiny::textInput("uucop_id_email", paste0("Your ", domain, " email address"), ""),
      if (!is.null(msg)) shiny::div(style = "color:#b00;", msg),
      footer = shiny::actionButton("uucop_id_submit", "Continue",
                                   class = "btn-primary"),
      easyClose = FALSE
    ))
  }
  show_prompt()

  shiny::observeEvent(input$uucop_id_submit, {
    email <- tolower(trimws(input$uucop_id_email %||% ""))
    if (!grepl(paste0("^[^@[:space:]]+@", gsub(".", "[.]", domain, fixed = TRUE), "$"), email)) {
      shiny::removeModal()
      show_prompt(paste0("Please enter a valid ", domain, " address."))
      return()
    }
    if (user_map_register(guid, email)) {
      shiny::removeModal()
    } else {
      shiny::removeModal()
      show_prompt("Could not save that just now - please try again.")
    }
  }, ignoreInit = TRUE)

  invisible(NULL)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
