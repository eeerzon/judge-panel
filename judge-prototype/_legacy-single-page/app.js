// King & Queen of the Pacific — Judge Panel Prototype
// Phase 1: Standby · Phase 2: Contestant Gallery · Phase 3: Scoring Page
// Phase 4: Review & Submit — completion review, official submission, locking.
// No backend — vanilla JS, in-memory state only. Visual/interaction prototype.
//
// PERSISTENCE: all scores/notes live only in the CONTESTANTS array in memory.
// A browser reload wipes everything back to DEMO_SCORES — acceptable here
// since this is a prototype, not the production app. See ../_docs/PROTOTYPE-NOTES.md
// for what the production Flutter build needs instead (local persistent
// storage + sync) before this behavior would be acceptable there.

(function () {
  // ================================================================
  // DATA
  // ================================================================

  // Scoring structure: sections with 1+ criteria. A section with a single
  // "standalone" criterion (Evening Gown, Stage Presence) shows its own
  // heading only — it is not a scorable parent on top of a scorable child.
  const SCORING_SECTIONS = [
    {
      heading: 'Interview',
      weight: 30,
      criteria: [
        { key: 'communication', label: 'Communication', weight: 10 },
        { key: 'confidence', label: 'Confidence', weight: 10, quickScore: [7, 8, 9, 10] },
        { key: 'substance', label: 'Substance', weight: 10 },
      ],
    },
    {
      heading: 'Evening Gown',
      weight: 30,
      criteria: [
        { key: 'eveningGown', label: 'Evening Gown', weight: 30, standalone: true },
      ],
    },
    {
      heading: 'Stage Presence',
      weight: 40,
      criteria: [
        { key: 'stagePresence', label: 'Stage Presence', weight: 40, standalone: true },
      ],
    },
  ];

  const CRITERIA_LIST = SCORING_SECTIONS.reduce(function (list, section) {
    return list.concat(section.criteria);
  }, []);

  const CRITERIA_KEYS = CRITERIA_LIST.map(function (c) { return c.key; });

  // Weighted average on a 1-10 scale, then ×10 to display on a /100 scale.
  // Criterion weights are percentages that sum to 100, so this is just
  // Σ(score × weight) / 10. Returns null (never 0) if any criterion is
  // still unscored — a missing score is never treated as a zero.
  function calcTotalScore(contestant) {
    const allFilled = CRITERIA_KEYS.every(function (key) { return contestant.scores[key] !== null; });
    if (!allFilled) return null;
    const weightedSum = CRITERIA_LIST.reduce(function (sum, c) {
      return sum + contestant.scores[c.key] * c.weight;
    }, 0);
    return weightedSum / 10;
  }

  const SCORE_MIN = 1;
  const SCORE_MAX = 10;
  const SCORE_STEP = 0.25;

  // name/country/photo transcribed directly from each contestant's supplied banner image.
  const CONTESTANTS = [
    { number: 1, name: 'Mrs Shaida', country: 'Malaysia', photo: 'assets/Miss 1.jpg' },
    { number: 2, name: 'Mrs Beathres', country: 'Borneo Island, Malaysia', photo: 'assets/Miss 2.jpg' },
    { number: 3, name: 'Mrs Baimar', country: 'Russia', photo: 'assets/Miss 3.jpg' },
    { number: 4, name: 'Miss Evgeniya', country: 'Russia', photo: 'assets/Miss 4.jpg' },
    { number: 5, name: 'Miss Nicole', country: 'Malaysia', photo: 'assets/Miss 5.jpg' },
    { number: 6, name: 'Miss Yuka', country: 'Japan', photo: 'assets/Miss 6.jpg' },
    { number: 7, name: 'Miss Park Jinah', country: 'Korea', photo: 'assets/Miss 7.jpg' },
    { number: 8, name: 'Miss Lee Seoyul', country: 'Korea', photo: 'assets/Miss 8.jpg' },
    { number: 9, name: 'Miss Veronika', country: 'Borneo Island, Indonesia', photo: 'assets/Miss 9.jpg' },
    { number: 10, name: 'Miss Bolormaa', country: 'Mongolia', photo: 'assets/Miss 10.jpg' },
    { number: 11, name: 'Mister Hady', country: 'Borneo Island, Indonesia', photo: 'assets/Mister 1.jpg' },
    { number: 12, name: 'Mister Nicholas', country: 'Malaysia', photo: 'assets/Mister 2.jpg' },
    { number: 13, name: 'Mister Azriq', country: 'Borneo Island, Brunei', photo: 'assets/Mister 3.jpg' },
    { number: 14, name: 'Mrs Edelisa', country: 'Portugal', photo: 'assets/Mister 4.jpg' },
    { number: 15, name: 'Mister Jerome', country: 'Philippines', photo: 'assets/Mister 5.jpg' },
  ];

  // A few pre-filled demo scores so Gallery/Phase 2 filters have something to show
  // on first load. Everything else starts genuinely empty (null) — a judge must
  // enter every score intentionally, never a silently-assumed default.
  const DEMO_SCORES = {
    1: { communication: 8.75, confidence: 9.00, substance: 8.50, eveningGown: 9.25, stagePresence: 9.00 },
    2: { communication: 8.50, confidence: 8.75, substance: 8.75, eveningGown: 9.00, stagePresence: 8.75 },
    3: { communication: 8.00, confidence: 8.25, substance: 7.75, eveningGown: null, stagePresence: null },
    6: { communication: 9.00, confidence: 9.25, substance: 9.00, eveningGown: 9.50, stagePresence: 9.25 },
    8: { communication: 7.75, confidence: 8.00, substance: null, eveningGown: null, stagePresence: null },
  };

  CONTESTANTS.forEach(function (c) {
    c.scores = {};
    CRITERIA_KEYS.forEach(function (key) {
      const demo = DEMO_SCORES[c.number];
      c.scores[key] = demo && demo[key] !== undefined ? demo[key] : null;
    });
    c.note = '';
    syncContestantStatus(c);
  });

  // Fallback hues (used only if a photo fails to load) — jewel tones matching the royal palette.
  const PHOTO_HUES = [345, 38, 275, 8, 25, 155, 320, 50, 300, 15, 165, 260, 335, 60, 200];

  // Title prefixes on the banners aren't part of the person's name — strip them before
  // computing initials so the photo-fallback monogram reads naturally (e.g. "Shaida" -> "S").
  const NAME_TITLES = ['mrs', 'miss', 'mister'];

  // ================================================================
  // STATUS DERIVATION (single source of truth = contestant.scores)
  // ================================================================

  function syncContestantStatus(contestant) {
    const scoredCount = CRITERIA_KEYS.filter(function (key) { return contestant.scores[key] !== null; }).length;
    if (scoredCount === 0) {
      contestant.status = 'not-started';
      contestant.draftProgress = null;
    } else if (scoredCount === CRITERIA_KEYS.length) {
      contestant.status = 'scored';
      contestant.draftProgress = null;
    } else {
      contestant.status = 'draft';
      contestant.draftProgress = [scoredCount, CRITERIA_KEYS.length];
    }
    return scoredCount;
  }

  // ================================================================
  // SCREEN ELEMENTS
  // ================================================================
  const standbyScreen = document.getElementById('standby-screen');
  const galleryScreen = document.getElementById('gallery-screen');
  const scoringScreen = document.getElementById('scoring-screen');
  const reviewScreen = document.getElementById('review-screen');
  const submittedScreen = document.getElementById('submitted-screen');

  const standbyActionBtn = document.getElementById('standby-action');
  const standbySubmittedNote = document.getElementById('standby-submitted-note');
  const clockEl = document.getElementById('clock');

  const grid = document.getElementById('contestant-grid');
  const filterPills = document.querySelectorAll('#gallery-screen .filter-pill');

  const countAllEl = document.getElementById('count-all');
  const countToScoreEl = document.getElementById('count-to-score');
  const countScoredEl = document.getElementById('count-scored');
  const progressCountEl = document.getElementById('progress-count');
  const progressBarFillEl = document.getElementById('progress-bar-fill');
  const reviewCtaBtn = document.getElementById('review-cta-btn');
  const gallerySubmittedBanner = document.getElementById('gallery-submitted-banner');

  // Review & Submit (Phase 4) elements
  const reviewBackBtn = document.getElementById('review-back');
  const reviewSummaryPanel = document.getElementById('review-summary-panel');
  const reviewFilterPills = document.querySelectorAll('#review-filter-group .filter-pill');
  const reviewCountAllEl = document.getElementById('review-count-all');
  const reviewCountAttentionEl = document.getElementById('review-count-attention');
  const reviewCountScoredEl = document.getElementById('review-count-scored');
  const reviewListEl = document.getElementById('review-list');
  const reviewFooterEl = document.getElementById('review-footer');

  const submitModalBackdrop = document.getElementById('submit-modal-backdrop');
  const submitModalBody = document.getElementById('submit-modal-body');
  const submitModalConfirmBody = document.getElementById('submit-modal-confirm-body');
  const submitModalFailedBody = document.getElementById('submit-modal-failed-body');
  const modalCancelBtn = document.getElementById('modal-cancel');
  const modalConfirmBtn = document.getElementById('modal-confirm');
  const modalFailedRetryBtn = document.getElementById('modal-failed-retry');

  const submittedStatEl = document.getElementById('submitted-stat');
  const submittedTimeEl = document.getElementById('submitted-time');
  const submittedReturnStandbyBtn = document.getElementById('submitted-return-standby');
  const submittedViewScoresBtn = document.getElementById('submitted-view-scores');

  // Scoring page elements
  const scoringBackBtn = document.getElementById('scoring-back');
  const scoringPositionEl = document.getElementById('scoring-position');
  const scoringPhotoImg = document.getElementById('scoring-photo');
  const scoringNumberEl = document.getElementById('scoring-number');
  const scoringNameEl = document.getElementById('scoring-name');
  const scoringCountryEl = document.getElementById('scoring-country');
  const scoringProgressEl = document.getElementById('scoring-progress');
  const totalScoreValueEl = document.getElementById('total-score-value');
  const scoringScrollEl = document.getElementById('scoring-scroll');
  const scoringPrevBtn = document.getElementById('scoring-prev');
  const scoringNextBtn = document.getElementById('scoring-next');
  const saveStatusEl = document.getElementById('save-status');
  const scoringPanelEl = document.querySelector('.scoring-panel');
  const scoringBodyEl = document.querySelector('.scoring-body');

  // Phase 5: connectivity + offline banner (all simulated — see dev panel below)
  const offlineBanner = document.getElementById('offline-banner');
  const standbyConnectionEl = document.getElementById('standby-connection-status');
  const galleryConnectionEl = document.getElementById('gallery-connection-status');

  // Phase 5: prototype-only dev panel
  const devPanel = document.getElementById('dev-panel');
  const devPanelToggle = document.getElementById('dev-panel-toggle');
  const devPanelBody = document.getElementById('dev-panel-body');
  const devConnectionBtns = document.querySelectorAll('[data-connection]');
  const devToggleSaveFailureBtn = document.getElementById('dev-toggle-save-failure');
  const devToggleSubmitFailureBtn = document.getElementById('dev-toggle-submit-failure');
  const devForceStandbyBtn = document.getElementById('dev-force-standby');

  let currentFilter = 'all';

  // Phase 4: Review & Submit state. Once submitted, scoring becomes
  // read-only everywhere (Gallery, Review, Scoring) — see the isSubmitted
  // checks throughout the Scoring Page section below.
  let isSubmitted = false;
  let submittedAt = null;

  // Which screen a judge entered the Scoring Page from — Back and the
  // last-contestant exit button return to that same screen instead of
  // always landing on Gallery, so opening a contestant from Review (to
  // finish a draft or just glance at a completed one) drops the judge
  // back into Review, not the photo grid they didn't come from.
  let scoringEntryOrigin = 'gallery'; // 'gallery' | 'review'

  // Phase 5: everything below is simulated for UX review — no real network,
  // storage or backend. See "Prototype Controls" in the UI and
  // PROTOTYPE-NOTES.md for what production must replace this with.
  let connectionState = 'synced'; // 'online' | 'offline' | 'syncing' | 'synced'
  let simulateSaveFailure = false;
  let simulateSubmitFailure = false;
  const STANDBY_TIMEOUT_MS = 45000; // short on purpose for demo/testing — see dev panel
  let standbyTimeoutId = null;

  // ================================================================
  // SCREEN SWITCHING
  // ================================================================
  function showScreen(screen) {
    [standbyScreen, galleryScreen, scoringScreen, reviewScreen, submittedScreen].forEach(function (s) {
      s.hidden = s !== screen;
    });
    resetStandbyTimer();
  }

  // Phase 5: privacy/screensaver timeout — a tablet left mid-judging on a
  // meal table should lock down to Standby on its own. This never touches
  // isSubmitted or any contestant score; it only swaps which screen is
  // visible, exactly like tapping the Standby button does.
  function resetStandbyTimer() {
    clearTimeout(standbyTimeoutId);
    if (standbyScreen.hidden) {
      standbyTimeoutId = setTimeout(function () {
        // Never yank the screen away from underneath an open confirmation —
        // that would be a confusing, easy-to-misread interruption right at
        // the one moment (submitting) a judge most needs to stay oriented.
        if (!submitModalBackdrop.hidden) return;
        showStandby();
      }, STANDBY_TIMEOUT_MS);
    }
  }

  ['pointerdown', 'keydown', 'wheel'].forEach(function (evt) {
    document.addEventListener(evt, resetStandbyTimer, { passive: true });
  });

  function showGallery() {
    updateCounts();
    renderGrid();
    showScreen(galleryScreen);
  }

  function showStandby() {
    standbySubmittedNote.hidden = !isSubmitted;
    showScreen(standbyScreen);
  }

  function backFromScoring() {
    if (scoringEntryOrigin === 'review') showReview();
    else showGallery();
  }

  standbyScreen.addEventListener('click', showGallery);
  standbyScreen.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      showGallery();
    }
  });

  standbyActionBtn.addEventListener('click', showStandby);

  // ================================================================
  // CONNECTIVITY (Phase 5 — simulated only, see dev panel)
  // ================================================================
  const CONNECTION_META = {
    online: { text: 'Online', modifier: 'is-neutral' },
    syncing: { text: 'Syncing…', modifier: 'is-neutral' },
    synced: { text: 'Synced', modifier: 'is-good' },
    offline: { text: 'Offline', modifier: 'is-warning' },
  };

  function renderConnectionStatus() {
    const meta = CONNECTION_META[connectionState];
    [standbyConnectionEl, galleryConnectionEl].forEach(function (el) {
      el.classList.remove('is-neutral', 'is-good', 'is-warning');
      el.classList.add(meta.modifier);
      el.querySelector('.connection-text').textContent = meta.text;
    });

    // Offline is the one state that needs to be impossible to miss — the
    // banner is informational only (never blocks judging) but it has to be
    // visible on whichever screen the judge is actually looking at, hence
    // living in the app shell rather than inside a single screen.
    offlineBanner.hidden = connectionState !== 'offline';
  }

  function setConnectionState(state) {
    connectionState = state;
    renderConnectionStatus();
  }

  renderConnectionStatus();

  // ================================================================
  // PROTOTYPE CONTROLS (Phase 5 dev panel — never shown to a real judge)
  // ================================================================
  devPanelToggle.addEventListener('click', function () {
    const collapsed = devPanel.classList.toggle('is-collapsed');
    devPanelBody.hidden = collapsed;
    devPanelToggle.setAttribute('aria-expanded', String(!collapsed));
  });

  devConnectionBtns.forEach(function (btn) {
    btn.addEventListener('click', function () {
      setConnectionState(btn.dataset.connection);
    });
  });

  devToggleSaveFailureBtn.addEventListener('click', function () {
    simulateSaveFailure = !simulateSaveFailure;
    devToggleSaveFailureBtn.textContent = 'Save failure: ' + (simulateSaveFailure ? 'On' : 'Off');
    devToggleSaveFailureBtn.classList.toggle('is-active', simulateSaveFailure);
  });

  devToggleSubmitFailureBtn.addEventListener('click', function () {
    simulateSubmitFailure = !simulateSubmitFailure;
    devToggleSubmitFailureBtn.textContent = 'Submit failure: ' + (simulateSubmitFailure ? 'On' : 'Off');
    devToggleSubmitFailureBtn.classList.toggle('is-active', simulateSubmitFailure);
  });

  devForceStandbyBtn.addEventListener('click', function () {
    clearTimeout(standbyTimeoutId);
    showStandby();
  });

  document.getElementById('dev-timeout-value').textContent = String(STANDBY_TIMEOUT_MS / 1000);

  // ================================================================
  // CLOCK (Phase 1)
  // ================================================================
  function updateClock() {
    const now = new Date();
    const h = String(now.getHours()).padStart(2, '0');
    const m = String(now.getMinutes()).padStart(2, '0');
    clockEl.textContent = h + ':' + m;
  }

  updateClock();
  setInterval(updateClock, 15000);

  // ================================================================
  // CONTESTANT GALLERY (Phase 2)
  // ================================================================
  function statusMeta(contestant) {
    if (contestant.status === 'scored') {
      return { className: 'status-scored', label: '✓ Scored' };
    }
    if (contestant.status === 'draft') {
      const progress = contestant.draftProgress || [0, 0];
      return { className: 'status-draft', label: 'Draft · ' + progress[0] + ' / ' + progress[1] + ' criteria' };
    }
    return { className: 'status-not-started', label: 'Not Scored' };
  }

  function initials(name) {
    return name
      .split(' ')
      .filter(function (part) { return part && NAME_TITLES.indexOf(part.toLowerCase()) === -1; })
      .slice(0, 2)
      .map(function (part) { return part[0]; })
      .join('')
      .toUpperCase();
  }

  function buildCard(contestant) {
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'contestant-card';
    card.setAttribute('role', 'listitem');
    card.dataset.status = contestant.status;

    const numberLabel = '#' + String(contestant.number).padStart(2, '0');
    const status = statusMeta(contestant);
    const hue = PHOTO_HUES[(contestant.number - 1) % PHOTO_HUES.length];
    const fallbackBg = 'linear-gradient(160deg, hsl(' + hue + ', 32%, 22%), hsl(' + hue + ', 28%, 12%))';

    card.setAttribute('aria-label', numberLabel + ' ' + contestant.name + ', ' + contestant.country + ', ' + status.label);

    card.innerHTML =
      '<div class="contestant-photo" style="background: ' + fallbackBg + ';">' +
        '<img src="' + contestant.photo + '" alt="" loading="lazy" ' +
          'onerror="this.style.display=\'none\'; this.nextElementSibling.style.display=\'flex\';" />' +
        '<span class="contestant-photo-fallback" style="display:none;">' + initials(contestant.name) + '</span>' +
      '</div>' +
      '<div class="contestant-body">' +
        '<span class="contestant-number">' + numberLabel + '</span>' +
        '<span class="contestant-name">' + contestant.name + '</span>' +
        '<span class="contestant-country">' + contestant.country + '</span>' +
        '<span class="contestant-status ' + status.className + '">' +
          '<span class="status-dot" aria-hidden="true"></span>' + status.label +
        '</span>' +
      '</div>';

    card.addEventListener('click', function () {
      scoringEntryOrigin = 'gallery';
      enterScoring(CONTESTANTS.indexOf(contestant));
    });

    return card;
  }

  function countByStatus() {
    let scored = 0;
    let draft = 0;
    let notStarted = 0;
    CONTESTANTS.forEach(function (c) {
      if (c.status === 'scored') scored++;
      else if (c.status === 'draft') draft++;
      else notStarted++;
    });
    return { scored: scored, draft: draft, notStarted: notStarted, total: CONTESTANTS.length };
  }

  function updateGalleryReviewCta() {
    const counts = countByStatus();
    gallerySubmittedBanner.hidden = !isSubmitted;
    if (isSubmitted) {
      reviewCtaBtn.textContent = 'View Submission';
    } else if (counts.scored === counts.total) {
      reviewCtaBtn.textContent = 'Review & Submit';
    } else {
      reviewCtaBtn.textContent = 'Review Progress';
    }
  }

  function matchesFilter(contestant, filter) {
    if (filter === 'all') return true;
    if (filter === 'scored') return contestant.status === 'scored';
    if (filter === 'to-score') return contestant.status === 'not-started' || contestant.status === 'draft';
    return true;
  }

  function renderGrid() {
    grid.innerHTML = '';
    const visible = CONTESTANTS.filter(function (c) { return matchesFilter(c, currentFilter); });

    if (visible.length === 0) {
      const empty = document.createElement('p');
      empty.className = 'empty-state';
      empty.textContent = 'No contestants in this filter.';
      grid.appendChild(empty);
      return;
    }

    visible.forEach(function (contestant) {
      grid.appendChild(buildCard(contestant));
    });
  }

  function updateCounts() {
    const total = CONTESTANTS.length;
    const scored = CONTESTANTS.filter(function (c) { return c.status === 'scored'; }).length;
    const toScore = total - scored;

    countAllEl.textContent = total;
    countToScoreEl.textContent = toScore;
    countScoredEl.textContent = scored;

    progressCountEl.textContent = scored + ' / ' + total;
    progressBarFillEl.style.width = Math.round((scored / total) * 100) + '%';

    updateGalleryReviewCta();
  }

  function setActiveFilter(filter) {
    currentFilter = filter;
    filterPills.forEach(function (pill) {
      const isActive = pill.dataset.filter === filter;
      pill.classList.toggle('is-active', isActive);
      pill.setAttribute('aria-selected', String(isActive));
    });
    renderGrid();
  }

  filterPills.forEach(function (pill) {
    pill.addEventListener('click', function () {
      setActiveFilter(pill.dataset.filter);
    });
  });

  reviewCtaBtn.addEventListener('click', showReview);

  // ================================================================
  // SCORING PAGE (Phase 3)
  // ================================================================
  let currentIndex = 0;
  let editingKey = null; // criterion key currently in manual-entry mode
  let editDraftValue = ''; // raw text currently in the manual-entry input (kept on validation error)
  let fieldErrors = {}; // { [criterionKey]: 'error message' }
  let noteOpen = false;
  let saveTimer = null;

  function getContestant() {
    return CONTESTANTS[currentIndex];
  }

  function enterScoring(index) {
    currentIndex = index;
    editingKey = null;
    fieldErrors = {};
    const c = getContestant();
    noteOpen = !!c.note;
    saveStatusEl.textContent = isSubmitted ? 'Locked' : 'Saved ✓';
    saveStatusEl.classList.remove('is-saving', 'is-error');
    showScreen(scoringScreen);
    renderScoringPage();
    // Every contestant switch starts scrolled to the top — a judge must see
    // the first criterion again, never land mid-scroll on the previous
    // contestant's position. Reset every scroll container that can hold the
    // scroll offset across the landscape/portrait layout split.
    scoringPanelEl.scrollTop = 0;
    scoringBodyEl.scrollTop = 0;
    scoringScrollEl.scrollTop = 0;
  }

  function formatScore(value) {
    return value.toFixed(2);
  }

  function triggerAutosave() {
    saveStatusEl.textContent = 'Saving…';
    saveStatusEl.classList.add('is-saving');
    saveStatusEl.classList.remove('is-error');
    clearTimeout(saveTimer);
    saveTimer = setTimeout(function () {
      saveStatusEl.classList.remove('is-saving');
      // Dev-panel-only simulation of a save that never confirms (e.g. the
      // tablet went offline mid-write) — the score the judge just entered
      // is untouched in memory, only the confirmation is withheld, exactly
      // as it would be on a real device with local-first persistence.
      if (simulateSaveFailure) {
        saveStatusEl.textContent = 'Unable to save';
        saveStatusEl.classList.add('is-error');
      } else {
        saveStatusEl.textContent = 'Saved ✓';
      }
    }, 700);
  }

  function setScore(key, value) {
    const c = getContestant();
    c.scores[key] = value;
    syncContestantStatus(c);
    delete fieldErrors[key];
    triggerAutosave();
    renderScoringPage();
  }

  function clampStep(raw) {
    // Snap floating-point drift from repeated +/- 0.25 taps (e.g. 8.049999...).
    return Math.round(raw / SCORE_STEP) * SCORE_STEP;
  }

  function handleIncrement(key) {
    const c = getContestant();
    const current = c.scores[key];
    const next = current === null ? SCORE_MIN : clampStep(current + SCORE_STEP);
    if (next > SCORE_MAX) return;
    setScore(key, next);
  }

  function handleDecrement(key) {
    const c = getContestant();
    const current = c.scores[key];
    if (current === null) return; // nothing to decrease from empty
    const next = clampStep(current - SCORE_STEP);
    if (next < SCORE_MIN) return;
    setScore(key, next);
  }

  function handleQuickScore(key, value) {
    setScore(key, value);
  }

  function openEdit(key) {
    const c = getContestant();
    editingKey = key;
    editDraftValue = c.scores[key] === null ? '' : formatScore(c.scores[key]);
    delete fieldErrors[key];
    renderScoringPage();
    const input = scoringScrollEl.querySelector('.score-value-input[data-key="' + key + '"]');
    if (input) {
      input.focus();
      input.select();
    }
  }

  function commitEdit(key, rawValue) {
    const raw = rawValue.trim();

    if (raw === '') {
      editingKey = null;
      setScore(key, null);
      return;
    }

    const num = Number(raw);

    if (Number.isNaN(num)) {
      editDraftValue = rawValue;
      fieldErrors[key] = 'Enter a number.';
      renderScoringPage();
      return;
    }
    if (num < SCORE_MIN) {
      editDraftValue = rawValue;
      fieldErrors[key] = 'Minimum score is ' + SCORE_MIN + '.';
      renderScoringPage();
      return;
    }
    if (num > SCORE_MAX) {
      editDraftValue = rawValue;
      fieldErrors[key] = 'Maximum score is ' + SCORE_MAX + '.';
      renderScoringPage();
      return;
    }
    const steps = num / SCORE_STEP;
    if (Math.abs(Math.round(steps) - steps) > 0.001) {
      editDraftValue = rawValue;
      fieldErrors[key] = 'Use increments of ' + SCORE_STEP + '.';
      renderScoringPage();
      return;
    }

    editingKey = null;
    setScore(key, clampStep(num));
  }

  function cancelEdit() {
    editingKey = null;
    renderScoringPage();
  }

  function renderCriterion(criterion) {
    const c = getContestant();
    const value = c.scores[criterion.key];
    const error = fieldErrors[criterion.key];
    const isEditing = editingKey === criterion.key;
    const canDecrement = value !== null && value > SCORE_MIN;
    const canIncrement = value === null || value < SCORE_MAX;

    let labelRow = '';
    if (!criterion.standalone) {
      labelRow =
        '<div class="criterion-label-row">' +
          '<span class="criterion-label">' + criterion.label + '</span>' +
          '<span class="criterion-weight">' + criterion.weight + '%</span>' +
        '</div>';
    }

    const valueHtml = isEditing
      ? '<input type="text" inputmode="decimal" class="score-value-input' + (error ? ' has-error' : '') + '" data-key="' + criterion.key + '" value="' + editDraftValue + '" />'
      : '<span class="score-value' + (value === null ? ' is-empty' : '') +
          '" data-action="edit" data-key="' + criterion.key + '" tabindex="0" role="button" aria-label="Edit ' + criterion.label + ' score, current value ' + (value === null ? 'not set' : formatScore(value)) + '"' +
        '>' + (value === null ? '—' : formatScore(value)) + '</span>';

    let quickScoreHtml = '';
    if (criterion.quickScore) {
      quickScoreHtml =
        '<div class="quick-score-row">' +
          '<span class="quick-score-label">Quick score</span>' +
          criterion.quickScore.map(function (v) {
            const selected = value === v ? ' is-selected' : '';
            return '<button type="button" class="quick-score-btn' + selected + '" data-action="quick" data-key="' + criterion.key + '" data-value="' + v + '">' + v + '</button>';
          }).join('') +
        '</div>';
    }

    return (
      '<div class="criterion-block">' +
        labelRow +
        '<div class="score-control">' +
          '<button type="button" class="score-btn score-btn-minus" data-action="decrement" data-key="' + criterion.key + '" aria-label="Decrease ' + criterion.label + ' score"' + (canDecrement ? '' : ' disabled') + '>−</button>' +
          valueHtml +
          '<button type="button" class="score-btn score-btn-plus" data-action="increment" data-key="' + criterion.key + '" aria-label="Increase ' + criterion.label + ' score"' + (canIncrement ? '' : ' disabled') + '>+</button>' +
        '</div>' +
        (error ? '<p class="score-error" role="alert">' + error + '</p>' : '') +
        quickScoreHtml +
      '</div>'
    );
  }

  function renderSection(section) {
    return (
      '<div class="scoring-section">' +
        '<div class="scoring-section-heading">' +
          '<span>' + section.heading + '</span>' +
          '<span class="scoring-section-weight">' + section.weight + '%</span>' +
        '</div>' +
        section.criteria.map(renderCriterion).join('') +
      '</div>'
    );
  }

  function renderNoteBlock(c) {
    if (!noteOpen) {
      return '<button type="button" class="add-note-btn" data-action="open-note">+ Add note</button>';
    }
    return (
      '<div class="note-block">' +
        '<label class="note-label" for="contestant-note">Note (optional)</label>' +
        '<textarea id="contestant-note" class="note-textarea" placeholder="Optional note about this contestant…">' + c.note + '</textarea>' +
      '</div>'
    );
  }

  function renderScoringPage() {
    const c = getContestant();
    const numberLabel = '#' + String(c.number).padStart(2, '0');

    scoringPositionEl.textContent = String(c.number).padStart(2, '0') + ' / ' + CONTESTANTS.length;
    scoringPhotoImg.src = c.photo;
    scoringNumberEl.textContent = numberLabel;
    scoringNameEl.textContent = c.name;
    scoringCountryEl.textContent = c.country;

    const scoredCount = syncContestantStatus(c);
    const isComplete = scoredCount === CRITERIA_KEYS.length;
    scoringProgressEl.textContent = isComplete
      ? '✓ Complete'
      : scoredCount + ' of ' + CRITERIA_KEYS.length + ' criteria scored';
    scoringProgressEl.classList.toggle('is-complete', isComplete);

    const totalScore = calcTotalScore(c);
    totalScoreValueEl.textContent = totalScore === null ? '—' : totalScore.toFixed(2);
    totalScoreValueEl.classList.toggle('is-empty', totalScore === null);

    scoringScrollEl.innerHTML = SCORING_SECTIONS.map(renderSection).join('') + renderNoteBlock(c);

    // Back/exit labels follow wherever the judge entered the Scoring Page
    // from — Gallery's photo grid or Review's checklist — so the round
    // trip feels like "returning", not a reset to a screen they didn't ask for.
    const backLabel = scoringEntryOrigin === 'review' ? 'Review' : 'Contestants';
    scoringBackBtn.textContent = '← ' + backLabel;

    scoringPrevBtn.disabled = currentIndex === 0;

    // The last contestant can't advance to a next one, so the primary
    // button becomes an explicit exit back to wherever the judge came
    // from instead of a dead-ended disabled button. Once submitted there
    // is nothing left to save, so drop the "Save &" framing entirely.
    const isLastContestant = currentIndex === CONTESTANTS.length - 1;
    scoringNextBtn.disabled = false;
    if (isSubmitted) {
      scoringNextBtn.textContent = isLastContestant ? ('Back to ' + backLabel + ' →') : 'Next →';
    } else {
      scoringNextBtn.textContent = isLastContestant ? ('Save & Back to ' + backLabel + ' →') : 'Save & Next →';
    }

    // Wire up manual-entry input (recreated on every render).
    const input = scoringScrollEl.querySelector('.score-value-input');
    if (input) {
      input.addEventListener('blur', function () {
        // Defer so a click on another control (e.g. a different criterion's
        // +/-) is fully handled before this re-renders the scoring list —
        // otherwise the re-render can remove the element mid-click.
        const key = input.dataset.key;
        const rawValue = input.value;
        setTimeout(function () {
          // Skip if Escape already cancelled this edit before blur landed.
          if (editingKey === key) commitEdit(key, rawValue);
        }, 0);
      });
      input.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') {
          e.preventDefault();
          input.blur();
        } else if (e.key === 'Escape') {
          e.preventDefault();
          cancelEdit();
        }
      });

      // A validation error re-renders the field (input is recreated) — refocus
      // it with the cursor at the end so the judge can correct the typo
      // immediately, without tapping back into the field.
      if (editingKey && fieldErrors[editingKey]) {
        input.focus();
        const len = input.value.length;
        input.setSelectionRange(len, len);
      }
    }

    // Wire up note textarea (recreated only when the note block is open).
    const noteTextarea = document.getElementById('contestant-note');
    if (noteTextarea) {
      noteTextarea.addEventListener('input', function () {
        c.note = noteTextarea.value;
      });
      noteTextarea.addEventListener('blur', function () {
        triggerAutosave();
      });
    }
  }

  // Single delegated click handler for the whole scoring scroll area —
  // criteria are rebuilt on every render, so listeners are attached once here.
  scoringScrollEl.addEventListener('click', function (e) {
    if (isSubmitted) return;
    const target = e.target.closest('[data-action]');
    if (!target) return;

    const action = target.dataset.action;
    const key = target.dataset.key;

    if (action === 'increment') handleIncrement(key);
    else if (action === 'decrement') handleDecrement(key);
    else if (action === 'edit') openEdit(key);
    else if (action === 'quick') handleQuickScore(key, Number(target.dataset.value));
    else if (action === 'open-note') {
      noteOpen = true;
      renderScoringPage();
      const ta = document.getElementById('contestant-note');
      if (ta) ta.focus();
    }
  });

  scoringScrollEl.addEventListener('keydown', function (e) {
    const target = e.target.closest('[data-action="edit"]');
    if (target && (e.key === 'Enter' || e.key === ' ')) {
      e.preventDefault();
      openEdit(target.dataset.key);
    }
  });

  // If a manual-entry field is mid-edit when the judge tries to navigate
  // away, force it to commit synchronously (the input's own blur handler
  // defers commitEdit by a tick — see its comment — which is too late to
  // gate a click handler running in the same turn). Returns false and
  // refocuses the field when the committed value is invalid, so navigation
  // never silently drops or skips past a bad score.
  function validateBeforeLeaving() {
    if (editingKey) {
      const input = scoringScrollEl.querySelector('.score-value-input[data-key="' + editingKey + '"]');
      if (input) commitEdit(editingKey, input.value);
    }
    return !(editingKey && fieldErrors[editingKey]);
  }

  scoringBackBtn.addEventListener('click', backFromScoring);

  scoringPrevBtn.addEventListener('click', function () {
    if (!validateBeforeLeaving()) return;
    if (currentIndex > 0) enterScoring(currentIndex - 1);
  });

  scoringNextBtn.addEventListener('click', function () {
    if (!validateBeforeLeaving()) return;
    if (!isSubmitted) triggerAutosave();
    if (currentIndex < CONTESTANTS.length - 1) {
      enterScoring(currentIndex + 1);
    } else {
      backFromScoring();
    }
  });

  // ================================================================
  // REVIEW & SUBMIT (Phase 4)
  // ================================================================
  let reviewFilter = 'all';

  function showReview() {
    renderReview();
    showScreen(reviewScreen);
  }

  function renderReview() {
    renderReviewSummary();
    updateReviewFilterCounts();
    renderReviewList();
    renderReviewFooter();
  }

  function renderReviewSummary() {
    const counts = countByStatus();
    const allScored = counts.scored === counts.total;
    const pct = Math.round((counts.scored / counts.total) * 100);

    reviewSummaryPanel.classList.toggle('is-ready', allScored && !isSubmitted);

    let noteHtml;
    if (isSubmitted) {
      noteHtml = '<p class="review-summary-note">Judging submitted. These scores are locked and can no longer be edited.</p>';
    } else if (allScored) {
      noteHtml = '<p class="review-summary-note">All contestants have been scored. Review your entries before submitting.</p>';
    } else {
      const remaining = counts.total - counts.scored;
      noteHtml = '<p class="review-summary-note">' + remaining + ' contestant' + (remaining === 1 ? '' : 's') +
        ' still need' + (remaining === 1 ? 's' : '') + ' attention. Complete all scores before final submission.</p>';
    }

    reviewSummaryPanel.innerHTML =
      '<div class="review-summary-top">' +
        '<span class="review-summary-count">' + counts.scored + ' / ' + counts.total + ' contestants scored</span>' +
      '</div>' +
      '<div class="review-progress-track"><div class="review-progress-fill" style="width:' + pct + '%"></div></div>' +
      noteHtml +
      '<div class="review-status-counts">' +
        '<span class="review-status-count review-status-count-scored"><span class="status-dot" aria-hidden="true"></span>✓ Scored ' + counts.scored + '</span>' +
        '<span class="review-status-count review-status-count-draft"><span class="status-dot" aria-hidden="true"></span>Draft ' + counts.draft + '</span>' +
        '<span class="review-status-count review-status-count-not-started"><span class="status-dot" aria-hidden="true"></span>Not Scored ' + counts.notStarted + '</span>' +
      '</div>';
  }

  function updateReviewFilterCounts() {
    const counts = countByStatus();
    reviewCountAllEl.textContent = counts.total;
    reviewCountAttentionEl.textContent = counts.draft + counts.notStarted;
    reviewCountScoredEl.textContent = counts.scored;
  }

  function matchesReviewFilter(contestant, filter) {
    if (filter === 'all') return true;
    if (filter === 'scored') return contestant.status === 'scored';
    if (filter === 'attention') return contestant.status !== 'scored';
    return true;
  }

  function buildReviewRow(contestant) {
    const index = CONTESTANTS.indexOf(contestant);
    const numberLabel = '#' + String(contestant.number).padStart(2, '0');
    const status = statusMeta(contestant);
    const hue = PHOTO_HUES[(contestant.number - 1) % PHOTO_HUES.length];
    const fallbackBg = 'linear-gradient(160deg, hsl(' + hue + ', 32%, 22%), hsl(' + hue + ', 28%, 12%))';

    const row = document.createElement('button');
    row.type = 'button';
    row.className = 'review-row';
    row.setAttribute('role', 'listitem');
    row.setAttribute('aria-label', numberLabel + ' ' + contestant.name + ', ' + contestant.country + ', ' + status.label);

    // Scored rows carry their status as a solid badge in the action column
    // instead of inline text — the badge already says "done" unambiguously,
    // so repeating it under the name would be redundant. Draft/Not Scored
    // keep the inline line since there's no badge there to say it instead.
    // Uses dedicated `is-*` modifiers (not `status.className`) so this never
    // collides with the shared `.status-draft`/`.status-not-started` pill
    // styling used by the Gallery card badges.
    const substatusHtml = contestant.status === 'scored'
      ? ''
      : '<span class="review-row-substatus is-' + contestant.status + '">' + status.label + '</span>';

    // Action column: a solid "done" badge for Scored, an equal-width
    // secondary button for anything still actionable, and nothing (but the
    // column stays reserved) once submitted — there's nothing left to do.
    let actionColHtml;
    if (contestant.status === 'scored') {
      actionColHtml = '<span class="review-row-badge">✓ Scored</span>';
    } else if (isSubmitted) {
      actionColHtml = '';
    } else if (contestant.status === 'draft') {
      actionColHtml = '<span class="review-row-action">Continue</span>';
    } else {
      actionColHtml = '<span class="review-row-action">Score</span>';
    }

    // Total Score column: same calcTotalScore() used on the Scoring Page —
    // one formula, two screens. Never a computed number for an incomplete
    // contestant, regardless of status.
    const total = calcTotalScore(contestant);
    const scoreValueHtml = total === null
      ? '<span class="review-row-score-value is-empty">—</span>'
      : '<span class="review-row-score-value">' + total.toFixed(2) + '</span>';

    row.innerHTML =
      '<div class="review-row-identity">' +
        '<div class="review-row-photo" style="background: ' + fallbackBg + ';">' +
          '<img src="' + contestant.photo + '" alt="" loading="lazy" onerror="this.style.display=\'none\';" />' +
        '</div>' +
        '<div class="review-row-main">' +
          '<div class="review-row-name-line">' +
            '<span class="review-row-number">' + numberLabel + '</span>' +
            '<span class="review-row-name">' + contestant.name + '</span>' +
          '</div>' +
          '<span class="review-row-country">' + contestant.country + '</span>' +
          substatusHtml +
        '</div>' +
      '</div>' +
      '<div class="review-row-score">' +
        '<span class="review-row-score-label">Total Score</span>' +
        scoreValueHtml +
        '<span class="review-row-score-max">/ 100</span>' +
      '</div>' +
      '<div class="review-row-action-col">' + actionColHtml + '</div>';

    row.addEventListener('click', function () {
      scoringEntryOrigin = 'review';
      enterScoring(index);
    });

    return row;
  }

  function renderReviewList() {
    reviewListEl.innerHTML = '';
    // Always contestant-number order — a judge's mental map of "who's
    // where" has to stay stable across screens, so incomplete contestants
    // never get bumped to the top just because they need attention.
    const visible = CONTESTANTS.filter(function (c) { return matchesReviewFilter(c, reviewFilter); });

    if (visible.length === 0) {
      const empty = document.createElement('p');
      empty.className = 'review-empty-state';
      empty.textContent = 'No contestants in this filter.';
      reviewListEl.appendChild(empty);
      return;
    }

    visible.forEach(function (c) {
      reviewListEl.appendChild(buildReviewRow(c));
    });
  }

  reviewFilterPills.forEach(function (pill) {
    pill.addEventListener('click', function () {
      reviewFilter = pill.dataset.reviewFilter;
      reviewFilterPills.forEach(function (p) {
        const isActive = p === pill;
        p.classList.toggle('is-active', isActive);
        p.setAttribute('aria-selected', String(isActive));
      });
      renderReviewList();
    });
  });

  function goToFirstIncomplete() {
    const index = CONTESTANTS.findIndex(function (c) { return c.status !== 'scored'; });
    if (index === -1) return;
    scoringEntryOrigin = 'review';
    enterScoring(index);
  }

  function renderReviewFooter() {
    const counts = countByStatus();
    const allScored = counts.scored === counts.total;

    if (isSubmitted) {
      reviewFooterEl.innerHTML =
        '<div class="review-footer-inner">' +
          '<span class="review-footer-note">Judging submitted — scores are locked.</span>' +
        '</div>';
      return;
    }

    if (allScored) {
      reviewFooterEl.innerHTML =
        '<div class="review-footer-inner">' +
          '<div class="review-footer-text">' +
            '<span class="review-footer-count">' + counts.total + ' / ' + counts.total + ' completed</span>' +
            '<span class="review-footer-hint">✓ Ready to submit</span>' +
          '</div>' +
          '<button type="button" class="review-footer-btn is-ready" id="review-submit-btn">Submit Judging</button>' +
        '</div>';
    } else {
      const remaining = counts.total - counts.scored;
      reviewFooterEl.innerHTML =
        '<div class="review-footer-inner">' +
          '<div class="review-footer-text">' +
            '<span class="review-footer-count">' + remaining + ' contestant' + (remaining === 1 ? '' : 's') + ' remaining</span>' +
            '<span class="review-footer-hint">Complete all contestants before submitting.</span>' +
          '</div>' +
          '<button type="button" class="review-footer-btn" id="review-complete-remaining-btn">Complete Remaining Scores</button>' +
        '</div>';
    }
  }

  // review-footer's inner content is rebuilt on every render, so the
  // click listener is delegated on the static container, same pattern as
  // the scoring page's criteria list.
  reviewFooterEl.addEventListener('click', function (e) {
    if (e.target.id === 'review-submit-btn') {
      openSubmitModal();
    } else if (e.target.id === 'review-complete-remaining-btn') {
      goToFirstIncomplete();
    }
  });

  reviewBackBtn.addEventListener('click', showGallery);

  // ---- Submit confirmation modal ----

  function showModalConfirmBody() {
    submitModalConfirmBody.hidden = false;
    submitModalFailedBody.hidden = true;
  }

  function showModalFailedBody() {
    submitModalConfirmBody.hidden = true;
    submitModalFailedBody.hidden = false;
    modalFailedRetryBtn.focus();
  }

  function openSubmitModal() {
    const counts = countByStatus();
    submitModalBody.textContent = 'You have scored all ' + counts.total + ' contestants.';
    modalConfirmBtn.disabled = false;
    modalConfirmBtn.textContent = 'Submit Scores';
    modalCancelBtn.disabled = false;
    showModalConfirmBody();
    submitModalBackdrop.hidden = false;
    modalConfirmBtn.focus();
  }

  function closeSubmitModal() {
    submitModalBackdrop.hidden = true;
  }

  modalCancelBtn.addEventListener('click', closeSubmitModal);

  // Click on the dimmed backdrop (not the panel itself) also cancels —
  // matches Escape below as a low-friction way out that still requires a
  // deliberate action, never an accidental stray tap on a row underneath.
  submitModalBackdrop.addEventListener('click', function (e) {
    if (e.target === submitModalBackdrop) closeSubmitModal();
  });

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && !submitModalBackdrop.hidden) {
      closeSubmitModal();
    }
  });

  function attemptSubmit() {
    // Simulated network round-trip — long enough to read as a real
    // submission, short enough not to feel broken. No backend in this
    // prototype; see PROTOTYPE-NOTES.md for what production needs instead.
    modalConfirmBtn.disabled = true;
    modalCancelBtn.disabled = true;
    modalConfirmBtn.textContent = 'Submitting…';
    setTimeout(function () {
      // Dev-panel-only simulation of a failed submit (e.g. lost connection
      // right at the moment of confirming) — scores stay exactly as they
      // were, nothing is cleared, the judge just needs to try again.
      if (simulateSubmitFailure) {
        showModalFailedBody();
        return;
      }
      isSubmitted = true;
      submittedAt = new Date();
      closeSubmitModal();
      showSubmitted();
    }, 900);
  }

  modalConfirmBtn.addEventListener('click', attemptSubmit);
  modalFailedRetryBtn.addEventListener('click', function () {
    showModalConfirmBody();
    modalConfirmBtn.disabled = false;
    modalCancelBtn.disabled = false;
    modalConfirmBtn.textContent = 'Submit Scores';
    attemptSubmit();
  });

  // ---- Submitted confirmation screen ----

  function showSubmitted() {
    const counts = countByStatus();
    submittedStatEl.textContent = counts.total + ' contestants scored';
    const h = String(submittedAt.getHours()).padStart(2, '0');
    const m = String(submittedAt.getMinutes()).padStart(2, '0');
    submittedTimeEl.textContent = 'Submitted at ' + h + ':' + m;
    showScreen(submittedScreen);
  }

  submittedReturnStandbyBtn.addEventListener('click', showStandby);
  submittedViewScoresBtn.addEventListener('click', showReview);

  // ================================================================
  // INITIAL RENDER
  // ================================================================
  updateCounts();
  renderGrid();
})();
