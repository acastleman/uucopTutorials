# =============================================================================
# Cross-platform viewer identity
# =============================================================================
# shinyapps.io and Posit Connect (server) populate `session$user`.
# Posit Connect Cloud does NOT — but it attaches the viewer's identity as a JWT
# in the `Posit-Connect-User-Session-Token` request header, which Shiny exposes
# as `session$request$HTTP_POSIT_CONNECT_USER_SESSION_TOKEN`.
#
# Verified 2026-08-04 on Connect Cloud in both a plain Shiny app and a learnr
# `shiny_prerendered` tutorial: the header is present on the websocket request,
# so `session$request` is sufficient in both content types.
#
# The token's `sub` claim is an opaque but STABLE per-user account GUID (its
# UUIDv7 timestamp decodes to the account creation date, not the session). It
# carries no email or username, so it is a pseudonymous identifier: it reliably
# distinguishes users, but resolving it to a student requires a mapping.
# =============================================================================

#' Decode a base64url-encoded string
#' @keywords internal
b64url_decode <- function(x) {
  x <- gsub("[[:space:]]", "", x)
  x <- gsub("-", "+", x, fixed = TRUE)
  x <- gsub("_", "/", x, fixed = TRUE)
  pad <- nchar(x) %% 4
  if (pad > 0) x <- paste0(x, strrep("=", 4 - pad))
  rawToChar(jsonlite::base64_dec(x))
}

#' Extract a claim from a JWT without verifying its signature
#'
#' Read-only use for identity logging. The token is issued and transported by
#' the hosting platform over its own encrypted channel; we are not using it as
#' a security boundary, so signature verification is not required here.
#'
#' @param token The raw JWT string.
#' @param claim Name of the claim to extract.
#' @return The claim as a character scalar, or `NULL`.
#' @keywords internal
jwt_claim <- function(token, claim = "sub") {
  if (!is.character(token) || length(token) != 1 || !nzchar(token)) return(NULL)
  parts <- strsplit(token, ".", fixed = TRUE)[[1]]
  if (length(parts) < 2) return(NULL)
  txt <- tryCatch(b64url_decode(parts[2]), error = function(e) NULL)
  if (is.null(txt)) return(NULL)
  payload <- tryCatch(jsonlite::fromJSON(txt), error = function(e) NULL)
  if (is.null(payload) || is.null(payload[[claim]])) return(NULL)
  as.character(payload[[claim]])
}

#' Viewer GUID from the Posit Connect Cloud session token
#'
#' @param session A Shiny session object.
#' @return Stable per-user GUID as a character scalar, or `NULL` if not running
#'   on Connect Cloud or no token is present.
#' @export
connect_cloud_user <- function(session = shiny::getDefaultReactiveDomain()) {
  rq <- tryCatch(session$request, error = function(e) NULL)
  if (is.null(rq)) return(NULL)
  tok <- tryCatch(rq$HTTP_POSIT_CONNECT_USER_SESSION_TOKEN,
                  error = function(e) NULL)
  jwt_claim(tok, "sub")
}

#' Resolve the authenticated viewer's identity across hosting platforms
#'
#' Tries, in order:
#' 1. `session$user` — populated on shinyapps.io and Posit Connect (server).
#' 2. The `sub` claim of Connect Cloud's `Posit-Connect-User-Session-Token`.
#' 3. `"unknown"`.
#'
#' On Connect Cloud the returned value is an opaque account GUID rather than a
#' username. It is stable across sessions and apps, so it is suitable as a join
#' key, but it must be mapped to a roster entry to identify a student by name.
#'
#' @param session A Shiny session object.
#' @return A character scalar; never `NULL`.
#' @export
uucop_user <- function(session = shiny::getDefaultReactiveDomain()) {
  if (!is.null(session) && !is.null(session$user) && nzchar(session$user)) {
    return(as.character(session$user))
  }
  sub <- connect_cloud_user(session)
  if (!is.null(sub) && nzchar(sub)) return(sub)
  "unknown"
}

#' Is this content running on Posit Connect Cloud?
#' @return `TRUE` or `FALSE`.
#' @export
on_connect_cloud <- function() {
  identical(Sys.getenv("POSIT_PRODUCT"), "CONNECT_CLOUD")
}
