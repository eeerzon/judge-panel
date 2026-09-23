// King & Queen of the Pacific — Judge Panel Prototype
// Shared localStorage-backed state — the multi-page replacement for the
// old single-page prototype's in-memory CONTESTANTS array. Every page reads
// and writes through this one module so there is exactly one place that
// knows the shape of prototype state, one storage key, and one set of
// status/total-score formulas (see PROTOTYPE-NOTES.md for why localStorage
// itself is not a production recommendation).

(function () {
  const DATA = window.JudgePrototypeData;
  const STORAGE_KEY = 'kreenJudgePrototype';

  function defaultState() {
    const scores = {};
    const notes = {};
    DATA.contestants.forEach(function (c) {
      const demo = DATA.demoScores[c.id];
      scores[c.id] = {};
      DATA.criteriaKeys.forEach(function (key) {
        scores[c.id][key] = demo && demo[key] !== undefined ? demo[key] : null;
      });
      notes[c.id] = '';
    });
    return {
      scores: scores,
      notes: notes,
      isSubmitted: false,
      submittedAt: null,
      currentContestantId: null,
      // Phase 5 simulated-only device/network states — see PROTOTYPE-NOTES.md.
      connectionState: 'synced', // 'online' | 'offline' | 'syncing' | 'synced'
      simulateSaveFailure: false,
      simulateSubmitFailure: false,
    };
  }

  function load() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return defaultState();
      const parsed = JSON.parse(raw);
      // Merge over defaults so a state shape added in a later prototype
      // revision (e.g. a new flag) doesn't crash on an older saved blob.
      return Object.assign(defaultState(), parsed);
    } catch (e) {
      return defaultState();
    }
  }

  function persist(state) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
      // Storage full/unavailable (private browsing, etc.) — prototype-only
      // concern, silently no-op rather than crash the page.
    }
  }

  let state = load();

  function getState() {
    return state;
  }

  function save() {
    persist(state);
  }

  function resetState() {
    state = defaultState();
    persist(state);
  }

  // ---- Business helpers (single source of truth — never duplicate these) ----

  function getContestant(id) {
    return DATA.contestants.find(function (c) { return c.id === Number(id); }) || null;
  }

  function getContestantScores(id) {
    return state.scores[id] || {};
  }

  function getContestantStatus(id) {
    const scores = getContestantScores(id);
    const scoredCount = DATA.criteriaKeys.filter(function (key) { return scores[key] !== null && scores[key] !== undefined; }).length;
    if (scoredCount === 0) return { status: 'not-started', scoredCount: 0, total: DATA.criteriaKeys.length };
    if (scoredCount === DATA.criteriaKeys.length) return { status: 'scored', scoredCount: scoredCount, total: DATA.criteriaKeys.length };
    return { status: 'draft', scoredCount: scoredCount, total: DATA.criteriaKeys.length };
  }

  function isContestantComplete(id) {
    return getContestantStatus(id).status === 'scored';
  }

  // Weighted average on a 1-10 scale, then ×10 to display on a /100 scale.
  // Criterion weights are percentages that sum to 100, so this is just
  // Σ(score × weight) / 10. Returns null (never 0) if any criterion is
  // still unscored — a missing score is never treated as a zero. This is
  // the ONLY place this formula is implemented; Scoring Page and Review
  // both call this function rather than recomputing it themselves.
  function calculateContestantTotal(id) {
    if (!isContestantComplete(id)) return null;
    const scores = getContestantScores(id);
    const weightedSum = DATA.criteriaList.reduce(function (sum, c) {
      return sum + scores[c.key] * c.weight;
    }, 0);
    return weightedSum / 10;
  }

  function countByStatus() {
    let scored = 0, draft = 0, notStarted = 0;
    DATA.contestants.forEach(function (c) {
      const s = getContestantStatus(c.id).status;
      if (s === 'scored') scored++;
      else if (s === 'draft') draft++;
      else notStarted++;
    });
    return { scored: scored, draft: draft, notStarted: notStarted, total: DATA.contestants.length };
  }

  function areAllContestantsComplete() {
    return countByStatus().scored === DATA.contestants.length;
  }

  function isSubmitted() {
    return !!state.isSubmitted;
  }

  function setScore(id, key, value) {
    if (isSubmitted()) return; // read-only lock — see PROTOTYPE-NOTES.md
    if (!state.scores[id]) state.scores[id] = {};
    state.scores[id][key] = value;
    save();
  }

  function setNote(id, text) {
    if (isSubmitted()) return;
    state.notes[id] = text;
    save();
  }

  function getNote(id) {
    return state.notes[id] || '';
  }

  // Submission requires every contestant complete — enforced here (not just
  // in the UI) so no page can accidentally submit an incomplete round.
  function submitJudging() {
    if (!areAllContestantsComplete()) return false;
    state.isSubmitted = true;
    state.submittedAt = new Date().toISOString();
    save();
    return true;
  }

  function setCurrentContestantId(id) {
    state.currentContestantId = id;
    save();
  }

  function setConnectionState(value) {
    state.connectionState = value;
    save();
  }

  function setSimulateSaveFailure(value) {
    state.simulateSaveFailure = value;
    save();
  }

  function setSimulateSubmitFailure(value) {
    state.simulateSubmitFailure = value;
    save();
  }

  window.JudgeState = {
    getState: getState,
    save: save,
    resetState: resetState,
    getContestant: getContestant,
    getContestantScores: getContestantScores,
    getContestantStatus: getContestantStatus,
    isContestantComplete: isContestantComplete,
    calculateContestantTotal: calculateContestantTotal,
    countByStatus: countByStatus,
    areAllContestantsComplete: areAllContestantsComplete,
    isSubmitted: isSubmitted,
    setScore: setScore,
    setNote: setNote,
    getNote: getNote,
    submitJudging: submitJudging,
    setCurrentContestantId: setCurrentContestantId,
    setConnectionState: setConnectionState,
    setSimulateSaveFailure: setSimulateSaveFailure,
    setSimulateSubmitFailure: setSimulateSubmitFailure,
  };
})();
