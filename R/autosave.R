# Client-side autosave of Shiny input values ---------------------------------
#
# Why this file exists:
#
#   Standard Shiny apps keep no state. A student filling out a lab who
#   refreshes the page, loses the shinyapps.io connection after an idle
#   timeout, or comes back the next day starts over with an empty form.
#
#   learnr tutorials do not have this problem: on a non-localhost deployment
#   learnr selects client_storage() (see learnr:::tutorial_storage), which
#   pushes each answer into the browser's own storage. This module gives plain
#   Shiny apps the same guarantee by the same route -- everything lives in the
#   student's browser, nothing is written to the server or to Google Sheets.
#
#   Consequences of that design, which are the same ones learnr already has:
#     * the draft follows the browser, not the shinyapps.io account, so it does
#       not travel from laptop to phone;
#     * on a shared browser profile the next person to open the app would see
#       the previous student's draft. app_autosave_clear() on successful submit
#       and the "Clear draft" link in the indicator are the mitigations.

#' JavaScript for client-side autosave of Shiny inputs
#'
#' Returns a self-contained `<script>` + `<style>` block that mirrors every
#' named input on the page into the browser's `localStorage` and restores them
#' the next time the same browser opens the app. Work survives a page refresh,
#' a shinyapps.io idle disconnect, and closing the tab for days.
#'
#' Include it once anywhere in the app UI (top of `fluidPage()` is fine). No
#' server-side call is required for saving or restoring; pair it with
#' [app_autosave_clear()] to discard the draft once a student has submitted.
#'
#' Saved and restored: text, textarea, numeric, password, select (including
#' selectize), radio groups, checkboxes, checkbox groups, and date inputs.
#' Not saved: file inputs, action buttons, and any input without an id.
#'
#' A draft is written only once at least one answer is non-empty, so simply
#' opening an app never creates one, and an accidentally blanked form never
#' overwrites a good draft with nothing.
#'
#' @param app_id Identifier for this app, used as the storage key. Must be
#'   unique per app (letters, numbers, `.`, `-`, `_`) so that two apps open in
#'   the same browser do not share a draft. Conventionally the same string
#'   passed to [session_tracking_server()], e.g. `"PKLab1"`.
#' @param exclude Character vector of input ids to leave out of the draft.
#' @param delay Debounce in milliseconds between the last keystroke and the
#'   write to `localStorage`. Defaults to 800.
#' @param indicator Show the small "Draft saved" pill in the lower-right corner,
#'   which also carries the "Clear draft" link. Defaults to `TRUE`.
#'
#' @return An [htmltools::HTML()] string to place in the UI.
#'
#' @examples
#' \dontrun{
#' ui <- fluidPage(
#'   app_autosave_js("PKLab1"),
#'   textInput("name", "Full Name"),
#'   actionButton("submit_btn", "Submit")
#' )
#'
#' server <- function(input, output, session) {
#'   observeEvent(input$submit_btn, {
#'     # ... send the submission ...
#'     app_autosave_clear(session)
#'   })
#' }
#' }
#' @export
app_autosave_js <- function(app_id,
                            exclude   = character(0),
                            delay     = 800,
                            indicator = TRUE) {

  if (!is.character(app_id) || length(app_id) != 1L || is.na(app_id) || !nzchar(app_id))
    stop("app_id must be a single non-empty string")
  if (!grepl("^[A-Za-z0-9._-]+$", app_id))
    stop("app_id may contain only letters, numbers, '.', '-' and '_': ", app_id)

  delay <- as.integer(delay)
  if (is.na(delay) || delay < 100L) stop("delay must be at least 100 (milliseconds)")

  exclude <- if (length(exclude)) as.character(exclude) else character(0)
  bad <- exclude[!grepl("^[A-Za-z0-9._-]+$", exclude)]
  if (length(bad))
    stop("exclude must be plain input ids: ", paste(bad, collapse = ", "))

  js <- .uucop_autosave_template
  js <- gsub("{{APP_ID}}",    app_id, js, fixed = TRUE)
  js <- gsub("{{DELAY}}",     delay,  js, fixed = TRUE)
  js <- gsub("{{EXCLUDE}}",
             as.character(jsonlite::toJSON(exclude, auto_unbox = FALSE)),
             js, fixed = TRUE)
  js <- gsub("{{INDICATOR}}", if (isTRUE(indicator)) "true" else "false",
             js, fixed = TRUE)

  htmltools::HTML(js)
}

#' Discard the saved autosave draft in the student's browser
#'
#' Sends a message to the client telling it to delete the `localStorage` draft
#' written by [app_autosave_js()]. Call it after a submission has succeeded, so
#' that reopening the app gives a clean form rather than the answers the
#' student has already turned in.
#'
#' Has no effect in an app that does not include [app_autosave_js()].
#'
#' @param session The Shiny session object.
#'
#' @return Invisible `NULL`.
#' @export
app_autosave_clear <- function(session = shiny::getDefaultReactiveDomain()) {
  if (is.null(session)) return(invisible(NULL))
  session$sendCustomMessage("uucop_autosave_clear", list(clear = TRUE))
  invisible(NULL)
}

# The template is kept as a single string so the whole client is one blob with
# no external asset to bundle, ship, or get stripped by .rscignore.
.uucop_autosave_template <- '
<style>
.uucop-autosave-pill {
  position: fixed; right: 14px; bottom: 14px; z-index: 1050;
  display: none; align-items: center; gap: 10px; max-width: 300px;
  background: #2c3e50; color: #fff;
  font-family: Arial, Helvetica, sans-serif; font-size: 12px; line-height: 1.35;
  padding: 7px 12px; border-radius: 14px;
  box-shadow: 0 2px 6px rgba(0,0,0,.25);
}
.uucop-autosave-pill.uucop-visible { display: flex; }
.uucop-autosave-pill a { color: #9ec9ff; text-decoration: underline; white-space: nowrap; }
.uucop-autosave-pill a:hover, .uucop-autosave-pill a:focus { color: #fff; }
@media print { .uucop-autosave-pill { display: none !important; } }
</style>
<script>
(function () {
  "use strict";

  var APP_ID    = "{{APP_ID}}";
  var STORE_KEY = "uucop_autosave_" + APP_ID;
  var SCHEMA    = 1;
  var DELAY     = {{DELAY}};
  var EXCLUDE   = {{EXCLUDE}};
  var INDICATOR = {{INDICATOR}};

  var $         = null;
  var restoring = false;
  var restored  = false;
  var baseline  = null;    // signature of the form as first rendered
  var timer     = null;
  var $pill     = null;
  var holdUntil = 0;   // keep the restore notice up past the save that follows it

  function trim(x) { return String(x == null ? "" : x).replace(/^\\s+|\\s+$/g, ""); }
  function skip(id) { return !id || EXCLUDE.indexOf(id) !== -1; }
  function byId(id) { var el = document.getElementById(id); return el ? $(el) : $(); }

  // -- storage ---------------------------------------------------------------
  function readStore() {
    var raw = null, p = null;
    try { raw = window.localStorage.getItem(STORE_KEY); } catch (e) { return null; }
    if (!raw) return null;
    try { p = JSON.parse(raw); } catch (e) { return null; }
    if (!p || p.schema !== SCHEMA || !p.data) return null;
    return p;
  }

  function writeStore(data) {
    try {
      window.localStorage.setItem(STORE_KEY, JSON.stringify({
        schema: SCHEMA, app: APP_ID, saved: new Date().toISOString(), data: data
      }));
      return true;
    } catch (e) {
      return false;   // private browsing or quota exceeded
    }
  }

  function clearStore() {
    try { window.localStorage.removeItem(STORE_KEY); } catch (e) {}
  }

  // -- indicator -------------------------------------------------------------
  function ensurePill() {
    if (!INDICATOR) return null;
    if ($pill) return $pill;
    $pill = $(
      \'<div class="uucop-autosave-pill" role="status" aria-live="polite">\' +
      \'<span class="uucop-autosave-msg"></span>\' +
      \'<a href="#" class="uucop-autosave-clear">Clear draft</a></div>\'
    );
    $pill.find(".uucop-autosave-clear").on("click", function (e) {
      e.preventDefault();
      var ok = window.confirm(
        "Delete the draft saved in this browser and reload a blank form?\\n\\n" +
        "Anything you have not submitted will be lost."
      );
      if (ok) { clearStore(); window.location.reload(); }
    });
    $(document.body).append($pill);
    return $pill;
  }

  function say(msg) {
    var p = ensurePill();
    if (!p) return;
    p.find(".uucop-autosave-msg").text(msg);
    p.addClass("uucop-visible");
  }

  function clockTime(d) {
    try { return d.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }); }
    catch (e) { return d.toTimeString().slice(0, 5); }
  }

  function stamp(d) {
    var today = new Date();
    var sameDay = d.getFullYear() === today.getFullYear() &&
                  d.getMonth()    === today.getMonth() &&
                  d.getDate()     === today.getDate();
    if (sameDay) return clockTime(d);
    try {
      return d.toLocaleDateString([], { month: "short", day: "numeric" }) + ", " + clockTime(d);
    } catch (e) { return d.toDateString(); }
  }

  // -- reading the form ------------------------------------------------------
  function collect() {
    var data = {};

    $("input[type=\'text\'], input[type=\'number\'], input[type=\'password\'], textarea, select")
      .each(function () {
        if (skip(this.id)) return;
        if ($(this).closest(".shiny-date-input, .shiny-date-range-input").length) return;
        data[this.id] = { t: "v", v: $(this).val() };
      });

    $(".shiny-input-radiogroup, .shiny-input-checkboxgroup").each(function () {
      if (skip(this.id)) return;
      data[this.id] = {
        t: "grp",
        v: $(this).find("input:checked").map(function () { return this.value; }).get()
      };
    });

    $("input[type=\'checkbox\']").each(function () {
      if (skip(this.id)) return;
      if ($(this).closest(".shiny-input-checkboxgroup").length) return;
      data[this.id] = { t: "chk", v: !!this.checked };
    });

    $(".shiny-date-input").each(function () {
      if (skip(this.id)) return;
      data[this.id] = { t: "date", v: $(this).find("input").first().val() };
    });

    return data;
  }

  function sig(data) {
    try { return JSON.stringify(data); } catch (e) { return null; }
  }

  // Snapshot the form as first rendered, so later saves can tell a real edit
  // from an input that simply carries a default value.
  function setBaseline() {
    if (baseline === null) baseline = sig(collect());
  }

  // A date left at its default is not evidence that a student typed anything,
  // so it never counts as content on its own.
  function hasContent(data) {
    return Object.keys(data).some(function (id) {
      var r = data[id];
      if (!r) return false;
      if (r.t === "v")   return trim(r.v).length > 0;
      if (r.t === "grp") return (r.v || []).length > 0;
      if (r.t === "chk") return r.v === true;
      return false;
    });
  }

  // -- writing the form ------------------------------------------------------
  function applyValue(id, rec) {
    var $el = byId(id);
    if (!$el.length || !rec) return;

    if (rec.t === "v") {
      var el = $el[0];
      if (el.selectize) { el.selectize.setValue(rec.v, true); }
      else { $el.val(rec.v); }
      $el.trigger("change");

    } else if (rec.t === "grp") {
      var vals = rec.v || [];
      $el.find("input").prop("checked", false);
      vals.forEach(function (v) {
        $el.find("input").filter(function () { return this.value === String(v); })
           .prop("checked", true);
      });
      $el.trigger("change");

    } else if (rec.t === "chk") {
      $el.prop("checked", rec.v === true).trigger("change");

    } else if (rec.t === "date") {
      if (!trim(rec.v)) return;
      var $inp = $el.find("input").first();
      $inp.val(rec.v);
      if ($.fn.datepicker) {
        try { $inp.datepicker("update", rec.v); } catch (e) {}
      }
      $inp.trigger("changeDate").trigger("change");
      $el.trigger("change");
    }
  }

  function restore() {
    // One attempt only, whether or not a draft turned up -- otherwise the
    // ready() backstop can fire after the first save and re-announce it as a
    // restore.
    if (restored) return;
    restored = true;
    var payload = readStore();
    if (!payload || !hasContent(payload.data)) return;

    restoring = true;
    try {
      Object.keys(payload.data).forEach(function (id) {
        try { applyValue(id, payload.data[id]); } catch (e) {}
      });
    } finally {
      restoring = false;
    }

    var when = new Date(payload.saved);
    say(isNaN(when.getTime()) ? "Draft restored" : "Draft restored from " + stamp(when));
    // Restoring writes the values back through Shiny, which trips a save a
    // moment later. Hold the notice so the student actually sees it.
    holdUntil = new Date().getTime() + 8000;
  }

  // -- saving ----------------------------------------------------------------
  function save() {
    timer = null;
    var data = collect();
    // Write only once the form differs from how it first rendered. Checking for
    // non-empty values is not enough: an app whose inputs carry defaults (a
    // preset numericInput, a selected radio) looks "non-empty" untouched, and
    // an untouched load would then overwrite a real draft with nothing.
    if (baseline === null ? !hasContent(data) : sig(data) === baseline) return;
    if (!writeStore(data)) return;
    if (new Date().getTime() >= holdUntil) say("Draft saved " + clockTime(new Date()));
  }

  function scheduleSave() {
    if (restoring) return;   // our own restore writes -- not the student typing
    if (timer) window.clearTimeout(timer);
    timer = window.setTimeout(save, DELAY);
  }

  // -- boot ------------------------------------------------------------------
  function start() {
    $ = window.jQuery;

    $(document).on("input.uucopAutosave change.uucopAutosave changeDate.uucopAutosave",
                   "input, textarea, select", scheduleSave);

    $(window).on("beforeunload.uucopAutosave", function () {
      if (timer) { window.clearTimeout(timer); save(); }
    });

    $(document).on("shiny:sessioninitialized", function () {
      setBaseline();
      window.setTimeout(restore, 0);
    });

    // Backstop: if this script booted late and missed sessioninitialized, the
    // restored flag makes the second attempt a no-op.
    $(document).ready(function () {
      window.setTimeout(function () { setBaseline(); restore(); }, 750);
    });

    // Registered last, and guarded, so that a rejected handler can never take
    // the restore wiring above down with it. Shiny requires a handler that
    // takes exactly one argument.
    try {
      window.Shiny.addCustomMessageHandler("uucop_autosave_clear", function (message) {
        if (timer) { window.clearTimeout(timer); timer = null; }
        clearStore();
        say("Draft cleared \\u2014 submitted");
      });
    } catch (e) {
      if (window.console) window.console.warn("uucop autosave: " + e);
    }
  }

  function boot() {
    if (!window.jQuery || !window.Shiny || !window.Shiny.addCustomMessageHandler) {
      return window.setTimeout(boot, 50);
    }
    start();
  }

  boot();
})();
</script>
'
