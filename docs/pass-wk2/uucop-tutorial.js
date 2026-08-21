/* =============================================================
   UUCOP PASS Tutorial — shared interaction layer
   ----------------------------------------------------------------
   Drop into each tutorial's `www/` directory and load via the
   YAML header. The included script tag in your Rmd should look
   like:

     <script src="www/uucop-tutorial.js" defer></script>

   Per-tutorial configuration is read from a <script> block in
   your Rmd <head>, OR from window.UUCOP_TUTORIAL_CONFIG. Example:

     <script type="application/json" id="uucop-config">
     {
       "course":   "PHRM 707",
       "week":     "Week 3",
       "title":    "Spacing & Interleaving",
       "crumb":    "Pre-class tutorial",
       "logoUrl":  "www/UUCOP%20logo.png",
       "storageKey": "pass-wk3-spacing",
       "groups": [
         {"label": "Pre-class · 55 min",   "match": "welcome|primer|immediate"},
         {"label": "Content · 40 min",     "match": "forgetting|spaced|interleav|putting"},
         {"label": "Consolidate · 15 min", "match": "synthesis|model|arrive|next"}
       ]
     }
     </script>

   See Implementation Guide.html for full integration notes.
   ============================================================= */
(function() {
  'use strict';

  /* ───────── Configuration ───────── */
  var DEFAULT_CFG = {
    course: "PHRM 707",
    week: "Week 3",
    title: "Tutorial",
    crumb: "",
    logoUrl: "www/UUCOP%20logo.png",
    storageKey: "uucop-tutorial-progress",
    groups: [],
    // Optional. When present the header counter reports questions answered
    // (server-driven, cumulative across visits) instead of sections visited.
    // Absent -> the sections behaviour below is unchanged, which is what every
    // tutorial outside PHRM 707 relies on.
    //   "progress": { "target": 20, "label": "Questions" }
    progress: null
  };
  var PROGRESS_SEGS = 10;

  function readConfig() {
    var fromGlobal = window.UUCOP_TUTORIAL_CONFIG || {};
    var fromJSON = {};
    var el = document.getElementById('uucop-config');
    if (el && (el.type === 'application/json' || !el.type)) {
      try { fromJSON = JSON.parse(el.textContent); }
      catch (e) { console.warn('[uucop] uucop-config JSON parse failed:', e.message); }
    }
    var cfg = Object.assign({}, DEFAULT_CFG, fromJSON, fromGlobal);
    // Compile match strings to RegExp
    if (Array.isArray(cfg.groups)) {
      cfg.groups = cfg.groups.map(function(g) {
        if (typeof g.match === 'string') {
          try { g.match = new RegExp(g.match, 'i'); }
          catch (e) { console.warn('[uucop] group match regex invalid:', g.match); g.match = null; }
        }
        return g;
      });
    } else {
      cfg.groups = [];
    }
    return cfg;
  }

  var CFG = readConfig();

  function escapeHTML(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function(c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  /* ───────── Header injection ───────── */
  function injectHeader() {
    if (document.getElementById('uucop-header')) return;
    var host = document.querySelector('.pageContent.band') ||
               document.querySelector('.tutorial') ||
               document.body.firstElementChild;
    if (!host) return;

    var crumbExtra = CFG.crumb ? ' &middot; ' + escapeHTML(CFG.crumb) : '';
    var header = document.createElement('header');
    header.id = 'uucop-header';
    header.innerHTML = [
      '<a class="uucop-mark" href="#" aria-label="Union University College of Pharmacy">',
        '<img src="', escapeHTML(CFG.logoUrl), '" alt="UUCOP">',
      '</a>',
      '<span class="uucop-divider" aria-hidden="true"></span>',
      '<div class="uucop-titleblock">',
        '<div class="uucop-title">', escapeHTML(CFG.title), '</div>',
        '<div class="uucop-crumb">',
          escapeHTML(CFG.course),
          ' &middot; <b>', escapeHTML(CFG.week), '</b>',
          crumbExtra,
        '</div>',
      '</div>',
      '<div class="uucop-progress" aria-label="Tutorial progress">',
        '<span class="uucop-progress-label"></span>',
        '<span class="uucop-progress-segs"></span>',
        '<span class="uucop-progress-count"></span>',
        '<span class="uucop-progress-chip" hidden></span>',
      '</div>'
    ].join('');
    host.parentNode.insertBefore(header, host);

    if (CFG.progress) {
      var $lbl = header.querySelector('.uucop-progress-label');
      if ($lbl) $lbl.textContent = CFG.progress.label || 'Questions';
      var $wrap = header.querySelector('.uucop-progress');
      if ($wrap) {
        $wrap.title = 'Questions and time on task both count toward completion.';
      }
      // Placeholder until the server answers the readiness ping. An em dash
      // rather than 0 — a returning student's real count is not zero, and this
      // gap is also what a viewer of the statically rendered HTML will see.
      var $cnt = header.querySelector('.uucop-progress-count');
      if ($cnt) $cnt.textContent = '— / ' + (CFG.progress.target || '');
    }
  }

  /* ───────── Sidebar: numerals + group headings ───────── */
  function groupLabelFor(text) {
    for (var i = 0; i < CFG.groups.length; i++) {
      var g = CFG.groups[i];
      if (g && g.match instanceof RegExp && g.match.test(text)) return g.label;
    }
    return null;
  }

  function decorateSidebar() {
    var $list = $('.topicsList .nav, .topicsList .nav-pills').first();
    if (!$list.length || $list.data('uucop-decorated')) return;
    $list.data('uucop-decorated', true);

    var lastGroupLabel = null;
    var visibleIndex = 0;
    var firstGroupApplied = false;

    $list.children('li').each(function() {
      var $li = $(this);
      if ($li.hasClass('uucop-group')) return;
      var $a = $li.children('a').first();
      if (!$a.length) return;

      var text = $a.text().trim();

      // Group heading insertion
      var groupLabel = groupLabelFor(text);
      if (groupLabel && groupLabel !== lastGroupLabel) {
        var $g = $('<li class="uucop-group"></li>').text(groupLabel);
        if (!firstGroupApplied) { $g.addClass('first'); firstGroupApplied = true; }
        $li.before($g);
        lastGroupLabel = groupLabel;
      }

      // Two-digit numeral
      if (!$a.find('.uucop-num').length) {
        visibleIndex++;
        var num = (visibleIndex < 10 ? '0' : '') + visibleIndex;
        $a.prepend('<span class="uucop-num">' + num + '</span>');
      }
    });
  }

  /* ───────── Progress tracking ───────── */
  var visited;
  function loadVisited() {
    try {
      visited = new Set(JSON.parse(localStorage.getItem(CFG.storageKey) || '[]'));
    } catch (e) {
      visited = new Set();
    }
  }
  function saveVisited() {
    try { localStorage.setItem(CFG.storageKey, JSON.stringify(Array.from(visited))); }
    catch (e) { /* localStorage unavailable */ }
  }
  function markVisited(sec) {
    if (!sec) return;
    visited.add(sec);
    saveVisited();
  }

  function updateProgress() {
    var $items = $('.topicsList .nav > li.topic, .topicsList .nav-pills > li.topic');
    if (!$items.length) {
      $items = $('.topicsList .nav > li, .topicsList .nav-pills > li').not('.uucop-group');
    }
    var total = $items.length;
    var doneCount = 0;
    var currentIdx = -1;

    $items.each(function(idx) {
      var $li = $(this);
      var $a = $li.children('a').first();
      var hash = ($a.attr('href') || '').replace(/^#/, '');

      if (hash && visited.has(hash)) {
        $li.addClass('visited');
        doneCount++;
      } else {
        $li.removeClass('visited');
      }
      if ($li.hasClass('current')) currentIdx = idx;
    });

    // The header readout belongs to the question counter when one is
    // configured; the sidebar marking above is shared and always runs.
    if (CFG.progress) return;

    var $segs = $('.uucop-progress-segs');
    if ($segs.length && total > 0) {
      var html = '';
      for (var i = 0; i < total; i++) {
        var cls = '';
        if (i < doneCount) cls = ' class="done"';
        else if (i === currentIdx) cls = ' class="current"';
        html += '<span' + cls + '></span>';
      }
      $segs.html(html);
    }
    $('.uucop-progress-count').text(doneCount + ' / ' + total);
  }

  /* ───────── Answered-label memory
     The server's seed can lag what the student has actually done, by the event
     buffer (~20-25s) and then by the per-worker read cache. Those caches are
     per worker process and reloads are spread across workers, so consecutive
     loads can disagree and the count can fall — 5, then 4, then 5. We keep the
     labels this browser has been told about and union them into every render,
     so the number only ever climbs.

     These labels come from server pushes, i.e. submissions the recorder
     actually processed, never from the DOM. The one way this can over-report
     is a queued row that later fails a non-retryable write — in which case the
     graded number is the one that is wrong. ───────── */
  function answeredKey() { return (CFG.storageKey || 'uucop-tutorial') + ':answered'; }

  function loadAnswered() {
    try { return new Set(JSON.parse(localStorage.getItem(answeredKey()) || '[]')); }
    catch (e) { return new Set(); }
  }

  function mergeAnswered(labels) {
    var known = loadAnswered();
    if (!Array.isArray(labels)) return known;
    var grew = false;
    labels.forEach(function(l) {
      if (typeof l === 'string' && l && !known.has(l)) { known.add(l); grew = true; }
    });
    if (grew) {
      try { localStorage.setItem(answeredKey(), JSON.stringify(Array.from(known))); }
      catch (e) { /* private mode / quota — fall back to server count */ }
    }
    return known;
  }

  /* ───────── Question counter (server-driven)
     State arrives from uucopTutorials::uucop_progress_push(). It is cumulative
     across visits, seeded from the tracking sheet at session start, so it is
     the same number the tutorial is graded on. Deliberately absent: minutes.
     Showing "12 / 20 min" would tell every student that the time half of the
     rule is satisfiable by leaving the tab open. ───────── */
  /* The time half of the rule flips HERE, in the browser, off a single
     countdown -- never off a server heartbeat. progress.R used to re-push this
     state every 30 s so the chip could appear as minutes accrued; that kept the
     websocket busy for the whole life of the session, so shinyapps.io never saw
     an idle connection and never reclaimed the instance. An abandoned tab
     billed active hours all night (PASS-WK2, 12 straight hours, 2026-08-19
     20:00 -> 2026-08-20 07:00 CDT). One setTimeout does the same job for free.
     Do not reintroduce a heartbeat on the server for this. */
  var _lastProgress = null;
  var _minutesTimer = null;

  function scheduleMinutesFlip(ms) {
    if (_minutesTimer) { clearTimeout(_minutesTimer); _minutesTimer = null; }
    if (!isFinite(ms) || ms <= 0) return;
    // Capped so a bad payload cannot park a timer for days. Re-armed on every
    // push, so a long session still gets an accurate deadline as it goes.
    _minutesTimer = setTimeout(function () {
      _minutesTimer = null;
      if (!_lastProgress) return;
      _lastProgress.minutesInMs = 0;
      renderQuestionProgress(_lastProgress);
    }, Math.min(ms, 6 * 60 * 60 * 1000) + 250);
  }

  function renderQuestionProgress(st) {
    if (!CFG.progress) return;
    _lastProgress = st;
    var $count = $('.uucop-progress-count');
    var $segs  = $('.uucop-progress-segs');
    var $chip  = $('.uucop-progress-chip');
    var $wrap  = $('.uucop-progress');
    if (!$count.length) return;

    var target = Number(CFG.progress.target) || Number(st.target) || 0;

    // Union of what the sheet knows with what this browser has seen. Falls back
    // to the server's bare count if labels were not sent or storage is blocked.
    var answered;
    if (Array.isArray(st.labels)) {
      answered = Math.max(mergeAnswered(st.labels).size, Number(st.answered) || 0);
    } else {
      answered = Number(st.answered) || 0;
    }

    // Unauthenticated session: nothing this student does is being recorded.
    // Say so plainly — this is the state most worth catching early.
    // Visibility is driven by the .warn class, never by jQuery show/hide:
    // .show() writes an inline `display` that outranks the responsive rules in
    // the stylesheet, which left the segments on screen at phone widths and
    // squeezed the tutorial title down to an ellipsis.
    if (st.identified === false) {
      $wrap.addClass('warn');
      $segs.empty();
      $chip.prop('hidden', true).text('');
      $count.text('⚠ Not signed in');
      $wrap.attr('title', 'Your work is not being recorded. Reopen this ' +
                          'tutorial from the Student Portal while signed in.');
      return;
    }

    $wrap.removeClass('warn');

    var filled = 0;
    if (target > 0) {
      filled = Math.floor((Math.min(answered, target) / target) * PROGRESS_SEGS);
      if (answered > 0 && filled === 0) filled = 1;
    }
    var html = '';
    for (var i = 0; i < PROGRESS_SEGS; i++) {
      html += '<span' + (i < filled ? ' class="done"' : '') + '></span>';
    }
    $segs.html(html);

    $count.text(answered + ' / ' + target);

    // A failed seed read means anything answered on another device is missing,
    // so the count may be low and the completion claim cannot be trusted.
    if (st.cumulative === false) {
      $chip.prop('hidden', true).text('');
      $wrap.attr('title', 'Could not reach the record of your earlier visits, ' +
                          'so this count may be low.');
      return;
    }

    // Judge completion against the number actually on screen. Using the
    // server's own flag here would let the chip contradict the count whenever
    // the browser knows about a submission the seed has not caught up with.
    var questionsMet = answered >= target;
    var minutesMet;
    if (typeof st.minutesInMs === 'number') {
      minutesMet = st.minutesInMs <= 0;
      if (!minutesMet) scheduleMinutesFlip(st.minutesInMs);
    } else if (typeof st.minutesMet === 'boolean') {
      minutesMet = st.minutesMet;   // server predates the countdown
    } else {
      minutesMet = !!st.complete;
    }
    if (questionsMet && minutesMet) {
      $chip.text('✓ Complete').prop('hidden', false);
      $wrap.attr('title', 'Complete: you have met both the question and the ' +
                          'time-on-task requirement.');
    } else {
      $chip.prop('hidden', true).text('');
      $wrap.attr('title', 'Questions and time on task both count toward ' +
                          'completion.');
    }
  }

  var _readyFired = false;
  function announceProgressReady() {
    if (_readyFired || !CFG.progress) return;
    if (!window.Shiny || !Shiny.setInputValue) return;
    if (!document.getElementById('uucop-header')) return;
    _readyFired = true;
    Shiny.setInputValue('uucop_progress_ready', new Date().toISOString(),
                        { priority: 'event' });
  }

  /* ───────── Question button rename + textarea upgrade
     (preserved from v3.1 with no behavioral changes) ───────── */
  var _observedQs = new WeakSet();

  function renameBtnsIn(q) {
    q.querySelectorAll('button').forEach(function(btn) {
      var t = (btn.textContent || '').trim();
      if (t === 'Submit Answer' || t === 'Submit') btn.textContent = 'Reveal Model Answer';
    });
  }

  function upgradeTextInputs(q) {
    q.querySelectorAll('input[type="text"]').forEach(function(inp) {
      if (inp.dataset.taUpgraded) return;
      inp.dataset.taUpgraded = '1';
      var ta = document.createElement('textarea');
      ta.id = inp.id;
      ta.className = inp.className;
      ta.value = inp.value || '';
      ta.placeholder = inp.placeholder || '';
      ta.disabled = inp.disabled;
      ta.style.cssText = 'width:100%;box-sizing:border-box;resize:vertical;min-height:72px;overflow:hidden;';
      function fit() {
        ta.style.height = 'auto';
        ta.style.height = (ta.scrollHeight + 2) + 'px';
      }
      ta.addEventListener('input', function() {
        fit();
        if (window.Shiny && Shiny.setInputValue) Shiny.setInputValue(ta.id, ta.value);
      });
      inp.parentNode.replaceChild(ta, inp);
      fit();
      setTimeout(function() {
        if (window.Shiny && Shiny.unbindAll && Shiny.bindAll) {
          Shiny.unbindAll(ta.parentNode);
          Shiny.bindAll(ta.parentNode);
        }
      }, 50);
    });
  }

  function attachQuestionObserver(q) {
    if (_observedQs.has(q)) return;
    if (!q.querySelector('input[type="text"]')) return;
    _observedQs.add(q);
    renameBtnsIn(q);
    upgradeTextInputs(q);
    new MutationObserver(function() {
      renameBtnsIn(q);
      upgradeTextInputs(q);
    }).observe(q, { childList: true, subtree: true });
  }

  function scanAndAttach() {
    document.querySelectorAll('.tutorial-question.panel-body, .tutorial-question').forEach(attachQuestionObserver);
  }

  /* ───────── Section-event reporter (preserved from v3.1) ───────── */
  function reportSection() {
    var hash = window.location.hash;
    if (hash && typeof Shiny !== 'undefined' && Shiny.setInputValue) {
      Shiny.setInputValue('learnr_section', {
        section:   hash.replace(/^#/, ''),
        timestamp: new Date().toISOString()
      }, { priority: 'event' });
    }
  }

  /* ───────── Boot ───────── */
  function ready(fn) {
    if (document.readyState !== 'loading') fn();
    else document.addEventListener('DOMContentLoaded', fn);
  }

  var _handlerWired = false;
  function wireProgress() {
    if (!CFG.progress) return true;
    if (!window.Shiny || !Shiny.addCustomMessageHandler) return false;
    // Register before pinging, never after: the server replies to the ping, so
    // registering second would drop the seed on a fast connection.
    if (!_handlerWired) {
      Shiny.addCustomMessageHandler('uucop_progress', renderQuestionProgress);
      _handlerWired = true;
    }
    injectHeader();
    announceProgressReady();
    return _readyFired;
  }

  function boot() {
    loadVisited();
    injectHeader();
    patchJQueryScroll();

    if (location.hash) markVisited(location.hash.replace('#', ''));
    if (window.jQuery) reportSection();

    if (CFG.progress) {
      var pAttempts = 0;
      var pIv = setInterval(function() {
        pAttempts++;
        if (wireProgress() || pAttempts > 100) clearInterval(pIv);
      }, 200);
      document.addEventListener('shiny:connected', wireProgress);
    }

    var attempts = 0;
    var iv = setInterval(function() {
      attempts++;
      injectHeader();
      patchJQueryScroll();
      if (window.jQuery && $('.topicsList').length) {
        decorateSidebar();
        scanAndAttach();
        updateProgress();
        clearInterval(iv);
      }
      if (attempts > 80) clearInterval(iv);
    }, 200);

    // Re-scan when learnr swaps content
    new MutationObserver(scanAndAttach).observe(document.body, { childList: true, subtree: true });

    // Watch sidebar for current-section changes
    var sidebarObserver = new MutationObserver(function() { updateProgress(); });
    var startSidebarObserver = setInterval(function() {
      var el = document.querySelector('.topicsList');
      if (el) {
        sidebarObserver.observe(el, { attributes: true, subtree: true, attributeFilter: ['class'] });
        clearInterval(startSidebarObserver);
      }
    }, 200);

    window.addEventListener('hashchange', function() {
      markVisited(location.hash.replace('#', ''));
      reportSection();
      updateProgress();
      correctScrollForHeader();
    });
  }

  /* ───────── Header-aware scroll correction
     learnr scrolls via jQuery `$('html, body').animate({ scrollTop: ... })`
     when it transitions sections (Next Topic) AND when it reveals the
     next progressive-reveal subsection (the in-section Continue button).
     Neither case respects CSS scroll-padding-top or scroll-margin-top.
     We patch jQuery's animate to subtract our header offset from the
     target scrollTop, so the destination heading lands below the fixed
     header instead of behind it. ───────── */
  var HEADER_OFFSET = 80; // 64px header + 16px buffer

  function patchJQueryScroll() {
    if (!window.jQuery || window.__uucopScrollPatched) return false;
    var $fn = window.jQuery.fn;
    if (!$fn || !$fn.animate) return false;
    window.__uucopScrollPatched = true;
    var origAnimate = $fn.animate;
    $fn.animate = function(props) {
      if (props && typeof props === 'object' && typeof props.scrollTop === 'number') {
        props.scrollTop = Math.max(0, props.scrollTop - HEADER_OFFSET);
      }
      return origAnimate.apply(this, arguments);
    };
    return true;
  }

  function correctScrollForHeader() {
    // Backstop: if learnr scrolled without going through jQuery animate
    // (e.g. raw .scrollTop(value)), correct on hashchange.
    var hash = (location.hash || '').replace(/^#/, '');
    if (!hash) return;
    setTimeout(function() {
      var section = document.getElementById('section-' + hash) ||
                    document.getElementById(hash);
      if (!section) return;
      var rect = section.getBoundingClientRect();
      // Only correct if section heading is in the covered zone
      if (rect.top >= 0 && rect.top < HEADER_OFFSET - 4) {
        if (window.jQuery) $('html, body').stop(true);
        var targetY = rect.top + (window.pageYOffset || document.documentElement.scrollTop) - HEADER_OFFSET;
        window.scrollTo({ top: Math.max(0, targetY), behavior: 'auto' });
      }
    }, 550);
  }

  ready(boot);
})();
