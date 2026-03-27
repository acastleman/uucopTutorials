#' Extract finite numeric values from inputs
#'
#' Converts all arguments to numeric and returns only finite values. Useful for
#' computing statistics over Shiny text inputs where some fields may be blank.
#'
#' @param ... Values to coerce (typically `input$field` calls).
#' @return Numeric vector containing only finite values.
#' @export
nums <- function(...) {
  v <- suppressWarnings(as.numeric(c(...)))
  v[is.finite(v)]
}

#' Mean of finite numeric inputs
#'
#' @param ... Values passed to [nums()].
#' @return Numeric scalar, or `NA_real_` if no finite values.
#' @export
xmean <- function(...) {
  v <- nums(...)
  if (!length(v)) NA_real_ else mean(v)
}

#' Standard deviation of finite numeric inputs
#'
#' @param ... Values passed to [nums()].
#' @return Numeric scalar, or `NA_real_` if fewer than 2 finite values.
#' @export
xsd <- function(...) {
  v <- nums(...)
  if (length(v) < 2) NA_real_ else sd(v)
}

#' Relative standard deviation (% CV) of finite numeric inputs
#'
#' @param ... Values passed to [nums()].
#' @return Numeric scalar (percent), or `NA_real_` if fewer than 2 finite values.
#' @export
xsdp <- function(...) {
  v <- nums(...)
  if (length(v) < 2) NA_real_ else round(sd(v) / mean(v) * 100, 2)
}

#' Accuracy as percent of expected value
#'
#' @param m Observed mean (numeric scalar).
#' @param expected Expected (theoretical) value.
#' @return Numeric scalar (percent), or `NA_real_` if `m` is `NA`.
#' @export
xacc <- function(m, expected) {
  if (is.na(m)) NA_real_ else round(m / expected * 100, 2)
}

#' Format a number for display, returning an em dash for missing values
#'
#' @param x Value to format.
#' @param d Number of decimal places. Defaults to 3.
#' @return Character string.
#' @export
disp <- function(x, d = 3) {
  if (is.null(x) || length(x) == 0) return("\u2014")
  x <- suppressWarnings(as.numeric(x))
  if (is.na(x) || !is.finite(x)) "\u2014" else formatC(x, digits = d, format = "f")
}

#' CSS theme string for lab submission emails
#'
#' Returns an inline `<style>` block used in [build_lab_email_html()] and
#' the `build_html()` function in each lab Shiny app. Consistent dark-navy
#' header, bordered cells, and alternating row shading.
#'
#' @return Character string containing a `<style>` block.
#' @export
lab_css_theme <- function() {
  "
  <style>
    body { font-family: Arial, sans-serif; font-size: 14px; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 16px; }
    th { background: #2c3e50; color: white; padding: 7px 10px; text-align: left; }
    td { border: 1px solid #ccc; padding: 6px 10px; }
    tr:nth-child(even) td { background: #f5f5f5; }
    h3 { color: #2c3e50; border-bottom: 2px solid #2c3e50; padding-bottom: 4px; margin-top: 20px; }
    .meta { color: #555; font-size: 13px; margin-bottom: 16px; }
  </style>
  "
}
