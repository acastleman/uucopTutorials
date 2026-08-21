/* uucop-static.js — the whole runtime for a static UUCOP tutorial.
 *
 * Replaces, for read-and-answer tutorials, everything Shiny was doing:
 * question rendering, grading, retry, the 20/20 progress header, time on task,
 * and event logging. Costs zero shinyapps.io instance hours.
 *
 * WHAT IS DELIBERATELY DIFFERENT FROM THE SHINY VERSION
 *
 * 1. Time on task is ACTIVE time, not wall clock. The Shiny build computes
 *    minutes as difftime(Sys.time(), session_start), so an idle tab accrued
 *    credit -- progress.R:134 says as much ("Publishing 12 / 20 min invites a
 *    student to park the tab open"). Here a second only counts if the document
 *    is visible AND the student interacted within IDLE_GRACE_MS. That makes the
 *    20-minute half of 20/20 mean what it says.
 *
 * 2. Events flush with fetch(keepalive:true) on pagehide. That genuinely
 *    survives the tab closing, unlike a later() tick scheduled at disconnect on
 *    a shinyapps.io worker that is already suspended.
 *
 * 3. The browser reports events rather than a server observing them, so the
 *    token is what makes a row attributable. The token gates LOGGING, never
 *    reading -- the page and its answer key are public either way.
 */
(function (global) {
  "use strict";

  var TICK_MS        = 1000;
  var IDLE_GRACE_MS  = 60000;   // interaction older than this stops the clock
  var SEGS           = 10;
  var QUEUE_KEY      = "uucop-static-queue";
  var SEEN_KEY       = "uucop-static-seen";

  var cfg = null;
  var claims = null;            // {u: username, t: tutorial, exp: epoch seconds}
  var token = null;
  var sessionId = (global.crypto && global.crypto.randomUUID)
    ? global.crypto.randomUUID()
    : String(Date.now()) + "-" + Math.random().toString(36).slice(2);
  var activeSeconds = 0;
  var lastInteraction = Date.now();
  var answered = null;          // Set of labels, unioned across visits
  var minutesTimer = null;

  /* ---------- token ------------------------------------------------------ */

  function b64urlDecode(s) {
    s = s.replace(/-/g, "+").replace(/_/g, "/");
    while (s.length % 4) s += "=";
    try { return decodeURIComponent(escape(atob(s))); } catch (e) { return null; }
  }

  // Token arrives in the URL FRAGMENT, not the query string, so it is never
  // sent to GitHub's servers and never lands in their access logs.
  function readToken() {
    var m = /(?:^|[#&])t=([^&]+)/.exec(global.location.hash || "");
    if (!m) return false;
    token = m[1];
    var body = token.split(".")[0];
    var json = body ? b64urlDecode(body) : null;
    if (!json) return false;
    try { claims = JSON.parse(json); } catch (e) { return false; }
    // The page does NOT verify the signature -- it cannot, the secret is not
    // here. It reads the claims only to show the student who it thinks they
    // are. Verification happens in Postgres, where the secret lives.
    if (!claims || !claims.u) { claims = null; return false; }
    if (claims.exp && claims.exp * 1000 < Date.now()) { claims = null; return "expired"; }
    return true;
  }

  /* ---------- storage --------------------------------------------------- */

  function store(key, val) {
    try { global.localStorage.setItem(key, JSON.stringify(val)); } catch (e) {}
  }
  function load(key, fallback) {
    try {
      var v = global.localStorage.getItem(key);
      return v ? JSON.parse(v) : fallback;
    } catch (e) { return fallback; }
  }

  function seenKey() { return SEEN_KEY + ":" + cfg.tutorial + ":" + (claims ? claims.u : "anon"); }

  /* ---------- event logging --------------------------------------------- */

  function queue() { return load(QUEUE_KEY, []); }

  function enqueue(payload) {
    var q = queue();
    q.push(payload);
    store(QUEUE_KEY, q);
    renderLog(payload);
    flush(false);
  }

  function flush(keepalive) {
    var q = queue();
    if (!q.length) return;
    if (!cfg.supabaseUrl || !cfg.supabaseAnonKey || !token) {
      setStatus(q.length + " event(s) queued locally (no Supabase configured)");
      return;
    }
    var batch = q.slice();
    fetch(cfg.supabaseUrl + "/rest/v1/rpc/uucop_log_event", {
      method: "POST",
      keepalive: !!keepalive,
      headers: {
        "Content-Type": "application/json",
        "apikey": cfg.supabaseAnonKey,
        "Authorization": "Bearer " + cfg.supabaseAnonKey
      },
      body: JSON.stringify({ p_token: token, p_events: batch })
    }).then(function (r) {
      if (!r.ok) throw new Error("HTTP " + r.status);
      // Only clear what we sent; anything enqueued mid-flight survives.
      var rest = queue().slice(batch.length);
      store(QUEUE_KEY, rest);
      setStatus("flushed " + batch.length + " event(s)");
    }).catch(function (e) {
      setStatus("flush failed (" + e.message + ") — " + queue().length + " queued, will retry");
    });
  }

  function logEvent(kind, extra) {
    var p = {
      tutorial: cfg.tutorial,
      sessionId: sessionId,
      kind: kind,
      // Per-visit counter, restarting at 0 each page load. uucop_progress()
      // sums the per-session maxima to get cumulative time; do not change this
      // to a running total without changing that query too.
      activeSeconds: Math.round(activeSeconds),
      clientTs: new Date().toISOString()
    };
    for (var k in extra) if (Object.prototype.hasOwnProperty.call(extra, k)) p[k] = extra[k];
    enqueue(p);
  }

  /* ---------- progress header ------------------------------------------- */

  function renderProgress() {
    var $count = document.getElementById("count");
    var $segs  = document.getElementById("segs");
    var $chip  = document.getElementById("chip");
    var $wrap  = document.getElementById("progress");
    if (!$count) return;

    if (!claims) {
      $wrap.classList.add("warn");
      $segs.innerHTML = "";
      $chip.hidden = true;
      $count.textContent = "⚠ Not signed in";
      $wrap.title = "Your work is not being recorded. Open this tutorial from " +
                    "the Student Portal.";
      return;
    }
    $wrap.classList.remove("warn");

    var n = answered.size, target = cfg.minQuestions;
    var filled = target > 0 ? Math.floor((Math.min(n, target) / target) * SEGS) : 0;
    if (n > 0 && filled === 0) filled = 1;
    var html = "";
    for (var i = 0; i < SEGS; i++) html += "<span" + (i < filled ? ' class="done"' : "") + "></span>";
    $segs.innerHTML = html;
    $count.textContent = n + " / " + target;

    var minutesMet = activeSeconds >= cfg.minMinutes * 60;
    if (n >= target && minutesMet) {
      $chip.textContent = "✓ Complete";
      $chip.hidden = false;
      $wrap.title = "Complete: question and time-on-task requirements both met.";
    } else {
      $chip.hidden = true;
      // Same discipline as the Shiny build: never publish "12 / 20 min", or the
      // time half reads as something you can wait out.
      $wrap.title = "Questions and time on task both count toward completion.";
    }
  }

  /* ---------- active-time clock ----------------------------------------- */

  function noteInteraction() { lastInteraction = Date.now(); }

  function startClock() {
    ["pointerdown", "keydown", "scroll", "input", "focus"].forEach(function (ev) {
      global.addEventListener(ev, noteInteraction, { passive: true });
    });
    // A 1-second interval in the browser is free. This is exactly the work the
    // 30-second server heartbeat was doing, moved to where it costs nothing.
    global.setInterval(function () {
      if (document.visibilityState !== "visible") return;
      if (Date.now() - lastInteraction > IDLE_GRACE_MS) return;
      activeSeconds += TICK_MS / 1000;
      if (activeSeconds % 15 === 0) renderProgress();
    }, TICK_MS);
  }

  /* ---------- questions ------------------------------------------------- */

  function shuffle(a) {
    for (var i = a.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var t = a[i]; a[i] = a[j]; a[j] = t;
    }
    return a;
  }

  function recordAnswered(label) {
    if (answered.has(label)) return;
    answered.add(label);
    store(seenKey(), Array.from(answered));
    renderProgress();
  }

  function buildSingle(q, host) {
    var choices = q.choices.map(function (c, i) { return { c: c, i: i }; });
    if (q.random_answer_order !== false) shuffle(choices);

    var form = document.createElement("form");
    form.className = "uucop-q";
    var name = "q_" + q.label;
    form.innerHTML = '<p class="uucop-stem">' + q.prompt + "</p>";

    var list = document.createElement("div");
    list.className = "uucop-choices";
    choices.forEach(function (o) {
      var id = name + "_" + o.i;
      var row = document.createElement("label");
      row.className = "uucop-choice";
      row.setAttribute("for", id);
      row.innerHTML = '<input type="radio" id="' + id + '" name="' + name + '" value="' + o.i + '"> ' +
                      "<span>" + o.c.text + "</span>";
      list.appendChild(row);
    });
    form.appendChild(list);

    var btn = document.createElement("button");
    btn.type = "submit";
    btn.className = "uucop-submit";
    btn.textContent = "Submit answer";
    form.appendChild(btn);

    var fb = document.createElement("div");
    fb.className = "uucop-feedback";
    fb.hidden = true;
    form.appendChild(fb);

    var attempts = 0;
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var sel = form.querySelector('input[name="' + name + '"]:checked');
      if (!sel) return;
      attempts++;
      var picked = q.choices[Number(sel.value)];
      var right = !!picked.correct;

      fb.hidden = false;
      fb.className = "uucop-feedback " + (right ? "ok" : "no");
      fb.textContent = right ? (q.feedback && q.feedback.correct) || "Correct."
                             : (q.feedback && q.feedback.incorrect) || "Not quite.";

      recordAnswered(q.label);
      logEvent("question", {
        label: q.label, qkind: "single", correct: right,
        answer: picked.text, attempt: attempts
      });

      var retry = q.allow_retry && !right;
      form.querySelectorAll("input").forEach(function (el) { el.disabled = !retry; });
      if (retry) { btn.textContent = "Try again"; }
      else { btn.disabled = true; btn.textContent = right ? "Correct" : "Answer recorded"; }
    });

    host.appendChild(form);
  }

  function buildText(q, host) {
    var form = document.createElement("form");
    form.className = "uucop-q";
    form.innerHTML = '<p class="uucop-stem">' + q.prompt + "</p>";

    var ta = document.createElement("textarea");
    ta.className = "uucop-text";
    ta.rows = 6;
    ta.placeholder = q.placeholder || "";
    form.appendChild(ta);

    var btn = document.createElement("button");
    btn.type = "submit";
    btn.className = "uucop-submit";
    btn.textContent = "Submit answer";
    form.appendChild(btn);

    var fb = document.createElement("div");
    fb.className = "uucop-feedback";
    fb.hidden = true;
    form.appendChild(fb);

    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var txt = ta.value.trim();
      if (!txt) return;
      fb.hidden = false;
      fb.className = "uucop-feedback model";
      fb.textContent = q.model || "";
      recordAnswered(q.label);
      // Free text is never auto-graded -- `correct` stays null, exactly as
      // question_text() records it.
      logEvent("question", { label: q.label, qkind: "text", correct: null, answer: txt });
      btn.disabled = true;
      btn.textContent = "Answer recorded";
      ta.readOnly = true;
    });

    host.appendChild(form);
  }

  /* ---------- dev panel ------------------------------------------------- */

  function setStatus(s) {
    var el = document.getElementById("logstatus");
    if (el) el.textContent = s;
  }
  function renderLog(payload) {
    var el = document.getElementById("log");
    if (!el) return;
    el.textContent = JSON.stringify(payload, null, 2) + "\n" + el.textContent;
  }

  /* ---------- boot ------------------------------------------------------ */

  function start(options) {
    cfg = options || {};
    cfg.minQuestions = cfg.minQuestions || 20;
    cfg.minMinutes   = cfg.minMinutes   || 20;

    var tok = readToken();
    answered = new Set(load(seenKey(), []));

    var host = document.getElementById("questions");
    (global.UUCOP_QUESTIONS || []).forEach(function (q) {
      if (q.kind === "text") buildText(q, host); else buildSingle(q, host);
    });

    startClock();
    renderProgress();

    if (tok === "expired") {
      setStatus("token expired — reopen from the Student Portal to have work recorded");
    } else if (!tok) {
      setStatus("no token in the URL — running unattributed; open from the Student Portal to be recorded");
    } else {
      setStatus("signed in as " + claims.u + " — events will be attributed");
      logEvent("session_start", {});
    }

    // pagehide fires on tab close and on mobile backgrounding; keepalive lets
    // the request outlive the document. This is the piece Shiny cannot do.
    global.addEventListener("pagehide", function () {
      if (claims) logEvent("session_end", { activeSeconds: activeSeconds });
      flush(true);
    });
    global.addEventListener("visibilitychange", function () {
      if (document.visibilityState === "hidden") flush(true);
    });
  }

  global.UUCOP = { start: start, _state: function () {
    return { claims: claims, activeSeconds: activeSeconds,
             answered: answered ? Array.from(answered) : [], queued: queue().length };
  } };

})(window);
