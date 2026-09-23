// King & Queen of the Pacific — Judge Panel Prototype
// Shared "chrome" every page renders identically: the preview-mode banner,
// the Phase 5 offline banner + connection-status indicators, and the
// "Prototype Controls" dev panel. Extracted here (rather than duplicated
// in standby.js/contestants.js/scoring.js/review.js/submitted.js) so there
// is exactly one place that knows how these look and behave.
//
// Expects each page's HTML to include the standard chrome markup (see any
// pages/*.html for the block to copy) with these ids:
//   #preview-banner, #offline-banner, #dev-panel (+ its children),
//   and any number of elements with class="connection-status" to update.

(function () {
  const S = window.JudgeState;
  const Nav = window.JudgeNav;

  function initPreviewBanner() {
    const el = document.getElementById('preview-banner');
    if (!el) return;
    el.hidden = !Nav.isPreviewMode();
  }

  const CONNECTION_META = {
    online: { text: 'Online', modifier: 'is-neutral' },
    syncing: { text: 'Syncing…', modifier: 'is-neutral' },
    synced: { text: 'Synced', modifier: 'is-good' },
    offline: { text: 'Offline', modifier: 'is-warning' },
  };

  function renderConnectionStatus() {
    const state = S.getState();
    const meta = CONNECTION_META[state.connectionState] || CONNECTION_META.synced;
    document.querySelectorAll('.connection-status').forEach(function (el) {
      el.classList.remove('is-neutral', 'is-good', 'is-warning');
      el.classList.add(meta.modifier);
      const textEl = el.querySelector('.connection-text');
      if (textEl) textEl.textContent = meta.text;
    });
    const banner = document.getElementById('offline-banner');
    if (banner) banner.hidden = state.connectionState !== 'offline';
  }

  function initDevPanel() {
    const panel = document.getElementById('dev-panel');
    if (!panel) return;

    const toggle = document.getElementById('dev-panel-toggle');
    const body = document.getElementById('dev-panel-body');
    toggle.addEventListener('click', function () {
      const collapsed = panel.classList.toggle('is-collapsed');
      body.hidden = collapsed;
      toggle.setAttribute('aria-expanded', String(!collapsed));
    });

    document.querySelectorAll('[data-connection]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        S.setConnectionState(btn.dataset.connection);
        renderConnectionStatus();
      });
    });

    const saveFailureBtn = document.getElementById('dev-toggle-save-failure');
    if (saveFailureBtn) {
      const sync = function () {
        const on = S.getState().simulateSaveFailure;
        saveFailureBtn.textContent = 'Save failure: ' + (on ? 'On' : 'Off');
        saveFailureBtn.classList.toggle('is-active', on);
      };
      saveFailureBtn.addEventListener('click', function () {
        S.setSimulateSaveFailure(!S.getState().simulateSaveFailure);
        sync();
      });
      sync();
    }

    const submitFailureBtn = document.getElementById('dev-toggle-submit-failure');
    if (submitFailureBtn) {
      const sync = function () {
        const on = S.getState().simulateSubmitFailure;
        submitFailureBtn.textContent = 'Submit failure: ' + (on ? 'On' : 'Off');
        submitFailureBtn.classList.toggle('is-active', on);
      };
      submitFailureBtn.addEventListener('click', function () {
        S.setSimulateSubmitFailure(!S.getState().simulateSubmitFailure);
        sync();
      });
      sync();
    }

    const forceStandbyBtn = document.getElementById('dev-force-standby');
    if (forceStandbyBtn) {
      forceStandbyBtn.addEventListener('click', function () {
        Nav.goToStandby();
      });
    }

    const timeoutValueEl = document.getElementById('dev-timeout-value');
    if (timeoutValueEl) timeoutValueEl.textContent = String(window.JudgeChrome.STANDBY_TIMEOUT_MS / 1000);

    const resetBtn = document.getElementById('dev-reset-prototype');
    if (resetBtn) {
      resetBtn.addEventListener('click', function () {
        if (window.confirm('Reset prototype data?')) {
          S.resetState();
          window.location.reload();
        }
      });
    }
  }

  const STANDBY_TIMEOUT_MS = 45000; // short on purpose for demo/testing

  // Privacy/screensaver timeout — a tablet left mid-judging should lock down
  // to Standby on its own. Never touches isSubmitted or any score; it only
  // navigates, exactly like tapping the Standby button does. Disabled
  // entirely in preview mode so a reviewer isn't unexpectedly bounced to
  // Standby while looking at a page.
  let standbyTimeoutId = null;
  function initStandbyTimeout(onTimeout) {
    if (Nav.isPreviewMode()) return;
    function reset() {
      clearTimeout(standbyTimeoutId);
      standbyTimeoutId = setTimeout(onTimeout, STANDBY_TIMEOUT_MS);
    }
    ['pointerdown', 'keydown', 'wheel'].forEach(function (evt) {
      document.addEventListener(evt, reset, { passive: true });
    });
    reset();
  }

  function init(options) {
    options = options || {};
    initPreviewBanner();
    renderConnectionStatus();
    initDevPanel();
    if (options.standbyTimeout !== false) {
      initStandbyTimeout(function () { Nav.goToStandby(); });
    }
  }

  window.JudgeChrome = {
    init: init,
    renderConnectionStatus: renderConnectionStatus,
    STANDBY_TIMEOUT_MS: STANDBY_TIMEOUT_MS,
    clearStandbyTimeout: function () { clearTimeout(standbyTimeoutId); },
  };
})();
