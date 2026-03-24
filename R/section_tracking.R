#' Get the section tracking JavaScript tag
#'
#' Returns an HTML `<script>` tag that listens for URL hash changes (learnr
#' encodes section navigation in the hash) and fires a Shiny input event.
#' Include this in the tutorial Rmd before the first section heading.
#'
#' @return An [htmltools::HTML()] string containing the `<script>` block.
#' @export
section_tracking_js <- function() {
  htmltools::HTML('
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
')
}

#' Set up section navigation tracking in a learnr tutorial
#'
#' Call this in a `context="server"` chunk. Observes the `learnr_section` input
#' (fired by [section_tracking_js()]) and logs each section entry to the
#' `section_events` tab of the configured Google Sheet.
#'
#' **Important:** Pass `input` explicitly when calling from a learnr server chunk.
#' The default `parent.frame()` resolution is unreliable in learnr's execution
#' context. Example: `section_tracking_server(TUTORIAL_ID, input = input)`.
#'
#' @param app_id The app/tutorial identifier string.
#' @param session The Shiny session object.
#' @param input The Shiny input object. Must be passed explicitly in learnr.
#'
#' @return Invisible `NULL`.
#' @export
section_tracking_server <- function(app_id, session = shiny::getDefaultReactiveDomain(),
                                    input) {
  session_user <- if (!is.null(session$user) && nzchar(session$user)) {
    session$user
  } else {
    "unknown"
  }

  shiny::observeEvent(input$learnr_section, {
    sec_data <- input$learnr_section
    tryCatch({
      googlesheets4::sheet_append(
        Sys.getenv("GS4_SHEET_ID"),
        data.frame(
          user       = session_user,
          app        = app_id,
          date       = format(Sys.time(), "%Y-%m-%d"),
          section    = sec_data$section,
          entered_at = sec_data$timestamp,
          stringsAsFactors = FALSE
        ),
        sheet = "section_events"
      )
    }, error = function(e) message("Section event log failed: ", e$message))
  })

  invisible(NULL)
}
