/* uucop-static.js — static runtime for a converted UUCOP learnr tutorial.
 *
 * DESIGN: invent as little as possible. The page it runs in is the tutorial's
 * own prerendered HTML, styled by the real www/uucop-tutorial.css, with the
 * real www/uucop-tutorial.js drawing the header, sidebar numerals and group
 * headings. This file supplies only what Shiny used to:
 *
 *   1. a Shiny shim, so uucop-tutorial.js runs unmodified. Every Shiny call in
 *      it is already guarded, and it takes config from the #uucop-config JSON
 *      block, so it needs nothing but addCustomMessageHandler/setInputValue.
 *   2. question widgets rendered into learnr's own
 *      .tutorial-question[data-label] placeholders, using learnr's Bootstrap
 *      markup so the stylesheet applies with no new classes invented.
 *   3. the `uucop_progress` message, byte-compatible with what
 *      uucopTutorials::uucop_progress_push() sends -- including minutesInMs,
 *      so the real renderQuestionProgress() drives the header exactly as it
 *      does in the Shiny build.
 *   4. event logging, and time on task measured as ACTIVE time.
 *
 * Load order matters: jquery, THIS FILE, uucop-tutorial.js, questions.js, then
 * UUCOP.start(). The shim must exist before uucop-tutorial.js boots.
 */
(function (global) {
  "use strict";

  var TICK_MS       = 1000;
  var IDLE_GRACE_MS = 60000;   // interaction older than this stops the clock
  var QUEUE_KEY     = "uucop-static-queue";
  var SEEN_KEY      = "uucop-static-seen";

  var cfg = null, claims = null, token = null;
  var answered = new Set();
  var activeSeconds = 0, lastInteraction = Date.now();
  var sessionId = (global.crypto && global.crypto.randomUUID)
    ? global.crypto.randomUUID()
    : String(Date.now()) + "-" + Math.random().toString(36).slice(2);

  /* ---- Shiny shim (must be installed at load, before uucop-tutorial.js) --- */

  var handlers = {};
  if (!global.Shiny) {
    global.Shiny = {
      addCustomMessageHandler: function (name, fn) { handlers[name] = fn; },
      setInputValue: function (name) {
        // Mirrors the server's observeEvent(uucop_progress_ready, once = TRUE):
        // the client announces its header exists, we answer with the state.
        if (name === "uucop_progress_ready") pushProgress();
      },
      unbindAll: function () {}, bindAll: function () {}
    };
  }

  // Exactly the payload uucop_progress_push() builds. Keeping this identical is
  // the point: the header code that consumes it is the production file.
  function pushProgress() {
    var h = handlers["uucop_progress"];
    if (!h || !cfg) return;
    var minutes = activeSeconds / 60;
    try {
      h({
        labels:      Array.from(answered),
        answered:    answered.size,
        target:      cfg.minQuestions,
        cumulative:  true,
        identified:  !!claims,
        minutesMet:  minutes >= cfg.minMinutes,
        minutesInMs: Math.max(0, (cfg.minMinutes - minutes) * 60000),
        complete:    answered.size >= cfg.minQuestions && minutes >= cfg.minMinutes
      });
    } catch (e) { /* header not ready yet; the next push will land */ }
  }

  /* ---- token ------------------------------------------------------------ */

  function b64urlDecode(s) {
    s = s.replace(/-/g, "+").replace(/_/g, "/");
    while (s.length % 4) s += "=";
    try { return decodeURIComponent(escape(atob(s))); } catch (e) { return null; }
  }

  // Token rides in the URL FRAGMENT so it is never sent to GitHub's servers.
  function readToken() {
    var m = /(?:^|[#&])t=([^&]+)/.exec(global.location.hash || "");
    if (!m) return false;
    token = m[1];
    var json = b64urlDecode(token.split(".")[0]);
    if (!json) return false;
    try { claims = JSON.parse(json); } catch (e) { return false; }
    // The page cannot verify the signature -- the secret is not here. It reads
    // the claims only to show who it thinks the student is. Postgres verifies.
    if (!claims || !claims.u) { claims = null; return false; }
    if (claims.exp && claims.exp * 1000 < Date.now()) { claims = null; return "expired"; }
    return true;
  }

  /* ---- storage + logging ----------------------------------------------- */

  function store(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} }
  function load(k, d)  { try { var v = localStorage.getItem(k); return v ? JSON.parse(v) : d; }
                         catch (e) { return d; } }
  function seenKey()   { return SEEN_KEY + ":" + cfg.tutorial + ":" + (claims ? claims.u : "anon"); }
  function queue()     { return load(QUEUE_KEY, []); }

  function logEvent(kind, extra) {
    var p = {
      tutorial: cfg.tutorial, sessionId: sessionId, kind: kind,
      // Per-visit counter restarting at 0 each load. uucop_progress() sums the
      // per-session maxima; do not make this a running total without changing
      // that query too.
      activeSeconds: Math.round(activeSeconds),
      clientTs: new Date().toISOString()
    };
    for (var k in extra) if (Object.prototype.hasOwnProperty.call(extra, k)) p[k] = extra[k];
    var q = queue(); q.push(p); store(QUEUE_KEY, q);
    flush(false);
  }

  function flush(keepalive) {
    var q = queue();
    if (!q.length) return;
    if (!cfg.supabaseUrl || !cfg.supabaseAnonKey || !token) return;  // queued, unattributed
    var batch = q.slice();
    fetch(cfg.supabaseUrl + "/rest/v1/rpc/uucop_log_event", {
      method: "POST", keepalive: !!keepalive,
      headers: { "Content-Type": "application/json",
                 "apikey": cfg.supabaseAnonKey,
                 "Authorization": "Bearer " + cfg.supabaseAnonKey },
      body: JSON.stringify({ p_token: token, p_events: batch })
    }).then(function (r) {
      if (!r.ok) throw new Error("HTTP " + r.status);
      store(QUEUE_KEY, queue().slice(batch.length));  // keep anything enqueued mid-flight
    }).catch(function () { /* stays queued; retried on the next event */ });
  }

  /* ---- active-time clock ----------------------------------------------- */

  function startClock() {
    ["pointerdown", "keydown", "scroll", "input", "focus"].forEach(function (ev) {
      global.addEventListener(ev, function () { lastInteraction = Date.now(); }, { passive: true });
    });
    // Free in the browser. This is the work the 30-second server heartbeat was
    // doing, moved to where it costs no instance hours.
    global.setInterval(function () {
      if (document.visibilityState !== "visible") return;
      if (Date.now() - lastInteraction > IDLE_GRACE_MS) return;
      activeSeconds++;
      if (activeSeconds % 15 === 0) pushProgress();
    }, TICK_MS);
  }

  /* ---- question rendering --------------------------------------------- */

  function esc(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function shuffle(a) {
    for (var i = a.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var t = a[i]; a[i] = a[j]; a[j] = t;
    }
    return a;
  }

  function noteAnswered(label) {
    if (answered.has(label)) return;
    answered.add(label);
    store(seenKey(), Array.from(answered));
    pushProgress();
  }

  // Items whose correct and incorrect feedback are identical are
  // self-assessments, not graded items. The stylesheet labels those
  // .alert-success / "Self-assessment" rather than "Model answer".
  function isSelfAssessment(q) {
    return !!(q.feedback && q.feedback.correct &&
              q.feedback.correct === q.feedback.incorrect);
  }

  function alertEl(cls, text) {
    var d = document.createElement("div");
    d.className = "alert " + cls;
    d.textContent = text || "";
    return d;
  }

  function renderSingle(q, host) {
    var name = "sq_" + q.label;
    var order = q.choices.map(function (c, i) { return { c: c, i: i }; });
    if (q.random_answer_order) shuffle(order);

    // learnr's own Bootstrap markup, so uucop-tutorial.css applies untouched.
    var html = ['<div class="shiny-input-container">',
                '<label class="control-label">', esc(q.prompt), '</label>',
                '<div class="shiny-options-group">'];
    order.forEach(function (o) {
      html.push('<div class="radio"><label><input type="radio" name="', name,
                '" value="', o.i, '"> <span>', esc(o.c.text), '</span></label></div>');
    });
    html.push('</div></div>',
              '<button type="button" class="btn btn-primary">Submit Answer</button>');
    host.innerHTML = html.join("");

    var btn = host.querySelector("button");
    var attempts = 0, fb = null;
    // Two states, as in learnr: 'answer' grades the selection, 'retry' CLEARS
    // and hands the question back. Previously "Try Again" ran the grading branch
    // again, so it re-submitted the same still-selected wrong choice and looked
    // like it did nothing.
    var mode = "answer";

    function setInputsDisabled(v) {
      host.querySelectorAll("input").forEach(function (el) { el.disabled = v; });
    }

    function toAnswerMode() {
      mode = "answer";
      if (fb) { fb.remove(); fb = null; }      // drop the feedback, as learnr does
      setInputsDisabled(false);                 // ...and hand the choices back
      btn.className = "btn btn-primary";
      btn.textContent = "Submit Answer";
      // The previous selection is deliberately LEFT checked: learnr keeps it, so
      // a student can change one option rather than start from nothing.
    }

    btn.addEventListener("click", function () {
      if (mode === "retry") { toAnswerMode(); return; }

      var sel = host.querySelector('input[name="' + name + '"]:checked');
      if (!sel) return;
      attempts++;
      var picked = q.choices[Number(sel.value)];
      var right = !!picked.correct;
      var self = isSelfAssessment(q);

      if (fb) fb.remove();
      // learnr's semantic classes. alert-success is what uucop-tutorial.css
      // paints amber and labels "Self-assessment" -- correct for a genuine
      // self-assessment item, wrong for a graded correct answer, which is why
      // uucop-correct carries a green treatment and a "Correct" label instead.
      var cls = self ? "alert-success"
                     : (right ? "alert-success uucop-correct" : "alert-danger");
      fb = alertEl(cls, right ? (q.feedback && q.feedback.correct) || "Correct."
                              : (q.feedback && q.feedback.incorrect) || "Not quite.");
      host.appendChild(fb);

      noteAnswered(q.label);
      logEvent("question", { label: q.label, qkind: "single", correct: right,
                             answer: picked.text, attempt: attempts });

      // learnr disables the choices on every submission, retry or not.
      setInputsDisabled(true);

      if (q.allow_retry && !right && !self) {
        mode = "retry";
        btn.className = "btn btn-warning";      // learnr uses btn-warning here
        btn.textContent = "Try Again";
      } else {
        btn.disabled = true;
        btn.className = "btn btn-default";
        btn.textContent = self ? "Recorded" : (right ? "Correct" : "Answer Recorded");
      }
    });
  }

  function renderText(q, host) {
    host.innerHTML = ['<div class="shiny-input-container">',
      '<label class="control-label">', esc(q.prompt), '</label>',
      '<textarea class="form-control" rows="5" placeholder="',
      esc(q.placeholder || ""), '"></textarea></div>',
      // The real JS renames a "Submit Answer" button to this for text items;
      // emitting the final label directly avoids depending on that observer.
      '<button type="button" class="btn btn-primary">Reveal Model Answer</button>'
    ].join("");

    var ta = host.querySelector("textarea");
    var btn = host.querySelector("button");
    btn.addEventListener("click", function () {
      var txt = ta.value.trim();
      if (!txt) return;
      host.appendChild(alertEl("", q.model || ""));
      noteAnswered(q.label);
      // Free text is never auto-graded: correct stays null, as question_text()
      // records it.
      logEvent("question", { label: q.label, qkind: "text", correct: null, answer: txt });
      btn.disabled = true; btn.textContent = "Answer Recorded";
      ta.readOnly = true;
    });
  }

  function renderQuestions() {
    var missing = [];
    (global.UUCOP_QUESTIONS || []).forEach(function (q) {
      var host = document.querySelector('.tutorial-question[data-label="' + q.label + '"]');
      if (!host) { missing.push(q.label); return; }
      host.innerHTML = "";
      if (q.kind === "text") renderText(q, host); else renderSingle(q, host);
    });
    if (missing.length) {
      // Loud, because a silently unrendered question is a question the student
      // cannot answer and therefore cannot get credit for.
      console.error("[uucop-static] no placeholder in the page for: " + missing.join(", "));
    }
    return missing;
  }

  /* ---- confidence checkpoints ----------------------------------------- */
  // radioButtons() prerender as real HTML, so these arrive already styled. All
  // that is missing is recording the answer (the server's uiOutput gate was
  // stripped with the rest of the Shiny runtime).
  function wireConfidence() {
    document.querySelectorAll(".confidence-checkpoint input[type=radio]")
      .forEach(function (el) {
        el.addEventListener("change", function () {
          var label = el.name || "confidence";
          logEvent("confidence", { label: label, qkind: "rating", answer: el.value });
        });
      });
  }

  /* ---- section navigation --------------------------------------------- */
  // learnr shows one topic at a time and builds its rail client-side; the rail
  // skeleton is generated by build_static.R. Everything else about it is
  // handled by www/uucop-tutorial.js, which on `hashchange` marks the section
  // visited, persists that, re-runs updateProgress() and corrects the scroll
  // for the sticky header. So navigation here does exactly two things: drive
  // location.hash, and show the matching section. Do NOT set .visited
  // directly -- updateProgress() owns that class and would fight us.

  function sections() {
    return Array.prototype.slice.call(
      document.querySelectorAll('.topics > .section.level2'));
  }

  // "Next: Primer" beats "Continue".
  function nextLabel(sec) {
    var h = sec.querySelector('h2');
    var t = h ? h.textContent.trim() : '';
    return t ? 'Next: ' + t : 'Continue';
  }

  function showSection(id, push) {
    var all = sections();
    if (!all.length) return;
    var target = id && document.getElementById(id);
    if (!target || all.indexOf(target) === -1) target = all[0];

    // `.current` is LEARNR'S OWN class: tutorial-format.css carries
    // `.topics .section.level2 { display: none }` and
    // `.topics .section.level2.current { display: block }`. Toggling it means
    // the paging is done by the shipped stylesheet, not by a rule of ours.
    all.forEach(function (s) { s.classList.toggle('current', s === target); });

    document.querySelectorAll('.topicsList .nav > li').forEach(function (li) {
      var a = li.querySelector('a');
      var href = a && a.getAttribute('href');
      li.classList.toggle('current', href === '#' + target.id);
    });

    if (push && location.hash.replace(/^#/, '') !== target.id) {
      // Assigning location.hash fires hashchange, which is what lets the
      // production JS do its bookkeeping. That is the intent, not a side effect.
      location.hash = target.id;
    } else {
      global.scrollTo(0, 0);
    }
    logEvent("section", { label: target.id, qkind: "section" });
  }

  function addContinueButtons() {
    var all = sections();
    all.forEach(function (s, i) {
      if (s.querySelector('.topicActions')) return;
      // learnr's own .topicActions, so tutorial-format.css spaces it.
      var wrap = document.createElement('div');
      wrap.className = 'topicActions';
      var next = all[i + 1];

      if (i > 0) {
        var back = document.createElement('button');
        back.type = 'button';
        back.className = 'btn btn-default uucop-prev';
        back.textContent = 'Back';
        back.addEventListener('click', function () { showSection(all[i - 1].id, true); });
        wrap.appendChild(back);
      }

      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'btn btn-primary uucop-next';
      // Name the destination rather than saying "Continue" -- the reader can
      // see where they are going, and it doubles as a section preview.
      b.textContent = next ? nextLabel(next) : 'Back to the start';
      b.addEventListener('click', function () {
        showSection(next ? next.id : all[0].id, true);
      });
      wrap.appendChild(b);
      s.appendChild(wrap);
    });
  }

  function startNav() {
    if (!sections().length) return;
    addContinueButtons();
    document.querySelectorAll('.topicsList .nav > li > a').forEach(function (a) {
      a.addEventListener('click', function (e) {
        e.preventDefault();
        showSection((a.getAttribute('href') || '').replace(/^#/, ''), true);
      });
    });
    global.addEventListener('hashchange', function () {
      // Strip the auth token so it is never mistaken for a section id.
      var h = location.hash.replace(/^#/, '');
      if (/^t=/.test(h)) return;
      showSection(h, false);
    });
    var initial = location.hash.replace(/^#/, '');
    showSection(/^t=/.test(initial) ? null : initial, false);
  }

  /* ---- progressive reveal -------------------------------------------- */
  // learnr's mechanism, observed on the live tutorial and reproduced with its
  // own classes so tutorial-format.css does all the showing and hiding:
  //   .section.level3.hide      -> hidden (Bootstrap display:none !important)
  //   .section.level3.showSkip  -> visible, and its .skip button becomes
  //                                display:inline-block via `.showSkip .skip`
  //   .section.level3.done      -> revealed already; gets the checkmark from
  //                                url(images/exerciseDone.svg)
  //   .section.level2.hideActions -> Next Topic suppressed until the section
  //                                is finished
  // build_static.R bakes the initial state so the first paint is correct; this
  // only advances it.

  var REVEAL_KEY = "uucop-static-revealed";

  function revealedStore() { return load(REVEAL_KEY + ":" + cfg.tutorial, {}); }

  function saveRevealed(secId, n) {
    var st = revealedStore();
    // Never move backwards: a student who has already opened four subsections
    // should not lose them by revisiting the section.
    if (!(st[secId] > n)) { st[secId] = n; store(REVEAL_KEY + ":" + cfg.tutorial, st); }
  }

  function subsections(sec) {
    return Array.prototype.slice.call(sec.querySelectorAll(':scope > .section.level3'));
  }

  // Show subsections 0..n-1, park the skip control on n-1, and release the
  // section's own Next Topic control once everything is out.
  function applyReveal(sec, n) {
    var subs = subsections(sec);
    if (!subs.length) return;
    n = Math.max(1, Math.min(n, subs.length));
    subs.forEach(function (s, i) {
      s.classList.toggle('hide', i >= n);
      s.classList.toggle('showSkip', i === n - 1 && n < subs.length);
      s.classList.toggle('done', i < n - 1);
    });
    sec.classList.toggle('hideActions', n < subs.length);
    saveRevealed(sec.id, n);
  }

  function revealedCount(sec) {
    var subs = subsections(sec);
    return subs.filter(function (s) { return !s.classList.contains('hide'); }).length || 1;
  }

  function wireProgressive() {
    var stored = revealedStore();
    sections().forEach(function (sec) {
      var subs = subsections(sec);
      if (subs.length < 2) return;
      // Only sections the converter marked progressive carry hideActions or a
      // hidden subsection; leave the opted-out ones (data-progressive=FALSE)
      // exactly as they are.
      var isProgressive = sec.classList.contains('hideActions') ||
                          subs.some(function (s) { return s.classList.contains('hide'); });
      if (!isProgressive) return;

      applyReveal(sec, stored[sec.id] || 1);

      subs.forEach(function (s) {
        var btn = s.querySelector('.exerciseActions .skip');
        if (!btn || btn.dataset.uucopWired) return;
        btn.dataset.uucopWired = '1';
        btn.addEventListener('click', function () {
          var next = revealedCount(sec) + 1;
          applyReveal(sec, next);
          logEvent("reveal", { label: sec.id, qkind: "subsection", answer: String(next) });
          var shown = subsections(sec)[next - 1];
          if (shown) shown.scrollIntoView({ block: 'start', behavior: 'smooth' });
        });
      });
    });
  }

  /* ---- Start Over ------------------------------------------------------ */
  // learnr clears server-side progress; here the equivalent is dropping every
  // key this page owns AND uucop-tutorial.js's own visited store (CFG.storageKey
  // from #uucop-config), otherwise the rail keeps its checkmarks and the reset
  // looks half-applied.
  function wireReset() {
    var btn = document.querySelector('.topicsFooter .resetButton');
    if (!btn) return;

    function reset() {
      if (!global.confirm('Start over? This clears your answers, your place in ' +
                          'this tutorial, and the questions-answered count on ' +
                          'this device.')) return;
      try {
        var cfgEl = document.getElementById('uucop-config');
        var storageKey = null;
        if (cfgEl) {
          try { storageKey = (JSON.parse(cfgEl.textContent) || {}).storageKey; } catch (e) {}
        }
        [seenKey(), REVEAL_KEY + ":" + cfg.tutorial, QUEUE_KEY]
          .concat(storageKey ? [storageKey] : [])
          .forEach(function (k) { localStorage.removeItem(k); });
      } catch (e) { /* storage blocked; the reload still resets the session */ }
      location.hash = '';
      location.reload();
    }

    btn.addEventListener('click', reset);
    // It is a <span> in learnr's markup, so it needs explicit keyboard support.
    btn.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); reset(); }
    });
  }

  /* ---- boot ----------------------------------------------------------- */

  function start(options) {
    cfg = options || {};
    cfg.minQuestions = cfg.minQuestions || 20;
    cfg.minMinutes   = cfg.minMinutes   || 20;

    var tok = readToken();
    answered = new Set(load(seenKey(), []));

    renderQuestions();
    wireConfidence();
    wireProgressive();
    wireReset();
    startNav();
    startClock();
    pushProgress();

    if (tok === true) logEvent("session_start", {});

    // pagehide fires on tab close and mobile backgrounding, and keepalive lets
    // the request outlive the document. This is the part Shiny cannot do: a
    // later() tick scheduled at disconnect never runs on a suspended worker.
    global.addEventListener("pagehide", function () {
      if (claims) logEvent("session_end", {});
      flush(true);
    });
    document.addEventListener("visibilitychange", function () {
      if (document.visibilityState === "hidden") flush(true);
    });
  }

  global.UUCOP = {
    start: start,
    _state: function () {
      return { claims: claims, activeSeconds: activeSeconds,
               answered: Array.from(answered), queued: queue().length,
               questions: (global.UUCOP_QUESTIONS || []).length };
    }
  };

})(window);
