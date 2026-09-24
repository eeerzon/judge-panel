// KREEN Judge Prototype — round-scoped local state (schema v2).
(function () {
  const DATA = window.JudgePrototypeData;
  const STORAGE_KEY = 'kreenJudgePrototype';
  const STATE_VERSION = 2;
  let activeRoundId = 1;
  function blankScores(id) { const result = {}; DATA.getRoundCriteria(id).forEach(function (criterion) { DATA.getRoundContestants(id).forEach(function (contestant) { if (!result[contestant.id]) result[contestant.id] = {}; result[contestant.id][criterion.key] = null; }); }); return result; }
  function applyDemo(scores) { Object.keys(DATA.demoScores).forEach(function (id) { if (scores[id]) Object.keys(DATA.demoScores[id]).forEach(function (key) { scores[id][key] = DATA.demoScores[id][key]; }); }); return scores; }
  function defaultState() { const scoresByRound = {}; const notesByRound = {}; DATA.rounds.forEach(function (round) { scoresByRound[round.id] = round.id === 1 ? applyDemo(blankScores(round.id)) : blankScores(round.id); notesByRound[round.id] = {}; }); return { stateVersion: STATE_VERSION, activeRoundId: 1, scoresByRound: scoresByRound, notesByRound: notesByRound, submissionByRound: {}, connectionState: 'synced', simulateSaveFailure: false, simulateSubmitFailure: false }; }
  function migrate(parsed) { if (!parsed || parsed.stateVersion === STATE_VERSION) return Object.assign(defaultState(), parsed || {}); const next = defaultState(); if (parsed.scores) next.scoresByRound[1] = Object.assign(next.scoresByRound[1], parsed.scores); if (parsed.notes) next.notesByRound[1] = parsed.notes; if (parsed.isSubmitted) next.submissionByRound[1] = { isSubmitted: true, submittedAt: parsed.submittedAt || null }; next.connectionState = parsed.connectionState || next.connectionState; next.simulateSaveFailure = !!parsed.simulateSaveFailure; next.simulateSubmitFailure = !!parsed.simulateSubmitFailure; return next; }
  function load() { try { const raw = localStorage.getItem(STORAGE_KEY); return raw ? migrate(JSON.parse(raw)) : defaultState(); } catch (e) { return defaultState(); } }
  function persist(value) { try { localStorage.setItem(STORAGE_KEY, JSON.stringify(value)); } catch (e) {} }
  let state = load();
  // A seeded Admin "Submitted" row has no real score sheet yet. On its first
  // reopen, complete only missing demo scores so the cross-mode flow is usable;
  // never overwrite scores already entered by the judge.
  const reference = state.submissionByRound && state.submissionByRound[1];
  if (reference && reference.referenceSubmission) {
    state.scoresByRound = state.scoresByRound || {};
    state.scoresByRound[1] = state.scoresByRound[1] || blankScores(1);
    DATA.getRoundContestants(1).forEach(function (contestant) {
      state.scoresByRound[1][contestant.id] = state.scoresByRound[1][contestant.id] || {};
      DATA.getRoundCriteria(1).forEach(function (criterion) { if (state.scoresByRound[1][contestant.id][criterion.key] == null) state.scoresByRound[1][contestant.id][criterion.key] = 8; });
    });
    reference.referenceSubmission = false;
    persist(state);
  }
  function getActiveRoundId() { return activeRoundId; }
  function getState() { return state; }
  function save() { persist(state); }
  function resetState() { state = defaultState(); activeRoundId = 1; persist(state); }
  function setActiveRound(id, persistChange) { if (!DATA.getRound(id)) return false; activeRoundId = Number(id); state.activeRoundId = activeRoundId; if (persistChange !== false) save(); return true; }
  function getRound() { return DATA.getRound(activeRoundId); }
  function getContestant(id) { return DATA.getRoundContestants(activeRoundId).find(function (contestant) { return contestant.id === Number(id); }) || null; }
  function getContestantScores(id) { return (state.scoresByRound[activeRoundId] || {})[id] || {}; }
  function getContestantStatus(id) { const scores = getContestantScores(id); const criteria = DATA.getRoundCriteria(activeRoundId); const scoredCount = criteria.filter(function (criterion) { return scores[criterion.key] !== null && scores[criterion.key] !== undefined; }).length; if (!scoredCount) return { status: 'not-started', scoredCount: 0, total: criteria.length }; if (scoredCount === criteria.length) return { status: 'scored', scoredCount: scoredCount, total: criteria.length }; return { status: 'draft', scoredCount: scoredCount, total: criteria.length }; }
  function isContestantComplete(id) { return getContestantStatus(id).status === 'scored'; }
  function calculateContestantTotal(id) { if (!isContestantComplete(id)) return null; const scores = getContestantScores(id); return DATA.getRoundCriteria(activeRoundId).reduce(function (sum, criterion) { return sum + scores[criterion.key] * criterion.weight; }, 0) / 10; }
  function countByStatus(roundId) { const id = Number(roundId || activeRoundId); let scored = 0, draft = 0, notStarted = 0; const criteria = DATA.getRoundCriteria(id); DATA.getRoundContestants(id).forEach(function (contestant) { const scores = ((state.scoresByRound || {})[id] || {})[contestant.id] || {}; const count = criteria.filter(function (criterion) { return scores[criterion.key] != null; }).length; if (count && count === criteria.length) scored++; else if (count) draft++; else notStarted++; }); return { scored: scored, draft: draft, notStarted: notStarted, total: DATA.getRoundContestants(id).length }; }
  function areAllContestantsComplete() { const counts = countByStatus(); return counts.total > 0 && counts.scored === counts.total; }
  function getSubmission(id) { return state.submissionByRound[Number(id || activeRoundId)] || { isSubmitted: false, submittedAt: null }; }
  function isSubmitted() { return !!getSubmission().isSubmitted; }
  function adminConfig() { try { return JSON.parse(localStorage.getItem('kreenAdminConfiguration') || '{}'); } catch (e) { return {}; } }
  function canJudgeRound(id) { const config = adminConfig(); const configured = config.judgeAssignments && config.judgeAssignments[Number(id)]; const assignments = configured || []; const own = assignments.find(function (item) { return Number(item.judgeId) === DATA.judge.number; }); return !!(DATA.getRound(id) && DATA.getRound(id).status === 'open' && (configured ? !!(own && own.assignmentStatus === 'assigned') : Number(id) === 1)); }
  function setScore(id, key, value) { if (isSubmitted() || !canJudgeRound(activeRoundId)) return; if (!state.scoresByRound[activeRoundId]) state.scoresByRound[activeRoundId] = blankScores(activeRoundId); if (!state.scoresByRound[activeRoundId][id]) state.scoresByRound[activeRoundId][id] = {}; state.scoresByRound[activeRoundId][id][key] = value; save(); }
  function setNote(id, text) { if (!isSubmitted() && canJudgeRound(activeRoundId)) { if (!state.notesByRound[activeRoundId]) state.notesByRound[activeRoundId] = {}; state.notesByRound[activeRoundId][id] = text; save(); } }
  function getNote(id) { return (state.notesByRound[activeRoundId] || {})[id] || ''; }
  function submitJudging() {
    if (!canJudgeRound(activeRoundId) || !areAllContestantsComplete()) return false;
    const previous = getSubmission(); const now = new Date().toISOString(); const resubmitted = previous.status === 'reopened';
    state.submissionByRound[activeRoundId] = Object.assign({}, previous, { isSubmitted: true, status: resubmitted ? 'resubmitted' : 'submitted', submittedAt: now, resubmittedAt: resubmitted ? now : previous.resubmittedAt || null }); save();
    try {
      const config = adminConfig(); config.submissionOverridesByRound = config.submissionOverridesByRound || {}; config.submissionOverridesByRound[activeRoundId] = config.submissionOverridesByRound[activeRoundId] || {}; config.submissionOverridesByRound[activeRoundId][DATA.judge.number] = { status: resubmitted ? 'resubmitted' : 'submitted', submittedAt: now };
      if (resubmitted) { const history = (config.reopensByRound || {})[activeRoundId] || []; for (let i = history.length - 1; i >= 0; i -= 1) { if (Number(history[i].judgeId) === DATA.judge.number && !history[i].resubmittedAt) { history[i].resubmittedAt = now; break; } } }
      config.auditEvents = config.auditEvents || []; config.auditEvents.push({ type: resubmitted ? 'resubmit' : 'submit', roundId: activeRoundId, judgeId: DATA.judge.number, at: now, actor: DATA.judge.name, reason: '' }); localStorage.setItem('kreenAdminConfiguration', JSON.stringify(config));
    } catch (e) {}
    return true;
  }
  function setCurrentContestantId(id) { state.currentContestantId = id; save(); }
  function setConnectionState(value) { state.connectionState = value; save(); }
  function setSimulateSaveFailure(value) { state.simulateSaveFailure = value; save(); }
  function setSimulateSubmitFailure(value) { state.simulateSubmitFailure = value; save(); }
  window.JudgeState = { getState: getState, save: save, resetState: resetState, setActiveRound: setActiveRound, getActiveRoundId: getActiveRoundId, getRound: getRound, getContestant: getContestant, getContestantScores: getContestantScores, getContestantStatus: getContestantStatus, isContestantComplete: isContestantComplete, calculateContestantTotal: calculateContestantTotal, countByStatus: countByStatus, areAllContestantsComplete: areAllContestantsComplete, getSubmission: getSubmission, isSubmitted: isSubmitted, canJudgeRound: canJudgeRound, setScore: setScore, setNote: setNote, getNote: getNote, submitJudging: submitJudging, setCurrentContestantId: setCurrentContestantId, setConnectionState: setConnectionState, setSimulateSaveFailure: setSimulateSaveFailure, setSimulateSubmitFailure: setSimulateSubmitFailure };
})();
