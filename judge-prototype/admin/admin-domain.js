// Canonical local Admin state for event masters and round configuration.
(function () {
  var DATA = window.KreenAdminData;
  var STORAGE_KEY = 'kreenAdminConfiguration';
  var SCHEMA_VERSION = 5;
  var DEFAULT_EVENT_SETTINGS = {
    eventName: 'King & Queen of the Pacific', eventYear: '2026', shortName: 'KQ Pacific',
    minScore: 1, maxScore: 10, step: 0.25,
    defaultCriterionRequired: true, defaultJudgeAssignmentRequired: true,
    resultVisibilityAfterFinalization: false
  };
  var seededContestants = [
    ['Mrs Shaida', 'Malaysia'], ['Mrs Beathres', 'Borneo Island, Malaysia'], ['Mrs Baimar', 'Russia'], ['Miss Evgeniya', 'Russia'], ['Miss Nicole', 'Malaysia'], ['Miss Yuka', 'Japan'], ['Miss Park Jinah', 'Korea'], ['Miss Lee Seoyul', 'Korea'], ['Miss Veronika', 'Borneo Island, Indonesia'], ['Miss Bolormaa', 'Mongolia'], ['Mister Hady', 'Borneo Island, Indonesia'], ['Mister Nicholas', 'Malaysia'], ['Mister Azriq', 'Borneo Island, Brunei'], ['Mrs Edelisa', 'Portugal'], ['Mister Jerome', 'Philippines']
  ].map(function (item, index) { return { id: index + 1, number: index + 1, name: item[0], country: item[1], photo: 'photos/contestant-' + String(index + 1).padStart(2, '0') + '.jpg', status: 'active' }; });
  function getSeedContestantPhoto(item) {
    var seed = seededContestants.find(function (candidate) { return Number(candidate.id) === Number(item.id); });
    return seed && item.name === seed.name && !item.photoCleared ? seed.photo : '';
  }
  var seededJudges = [
    { id: 1, displayNumber: '01', name: 'Ratih Pramesti', email: 'ratih@example.test', phone: '+62 811 0001', status: 'active' },
    { id: 2, displayNumber: '02', name: 'Dimas Ardiansyah', email: 'dimas@example.test', phone: '+62 811 0002', status: 'active' },
    { id: 3, displayNumber: '03', name: 'Amanda Wijaya', email: 'amanda@example.test', phone: '+62 811 0003', status: 'active' },
    { id: 4, displayNumber: '04', name: 'Budi Santoso', email: 'budi@example.test', phone: '+62 811 0004', status: 'active' },
    { id: 5, displayNumber: '05', name: 'Maria Tan', email: 'maria@example.test', phone: '+62 811 0005', status: 'active' },
    { id: 6, displayNumber: '06', name: 'Kevin Mahendra', email: 'kevin@example.test', phone: '+62 811 0006', status: 'active' },
    { id: 7, displayNumber: '07', name: 'Sari Handayani', email: 'sari@example.test', phone: '+62 811 0007', status: 'active' }
  ];
  function seedCriteria(roundId) {
    var specs = roundId === 1
      ? [{ id: 'interview', name: 'Interview', weight: 0, isScored: false, sequence: 1, isParent: true }, { id: 'communication', name: 'Communication', weight: 10, parentId: 'interview', sequence: 2 }, { id: 'confidence', name: 'Confidence', weight: 10, parentId: 'interview', sequence: 3 }, { id: 'substance', name: 'Substance', weight: 10, parentId: 'interview', sequence: 4 }, { id: 'evening-gown', name: 'Evening Gown', weight: 30, sequence: 5 }, { id: 'stage-presence', name: 'Stage Presence', weight: 40, sequence: 6 }]
      : roundId === 2
        ? [{ id: 'interview', name: 'Interview', weight: 30, sequence: 1 }, { id: 'stage-presence', name: 'Stage Presence', weight: 30, sequence: 2 }, { id: 'evening-gown', name: 'Evening Gown', weight: 40, sequence: 3 }]
        : [{ id: 'final-question', name: 'Final Question', weight: 40, sequence: 1 }, { id: 'overall-impression', name: 'Overall Impression', weight: 60, sequence: 2 }];
    return specs.map(function (item) { return Object.assign({ roundId: roundId, parentId: null, weight: 0, minScore: 1, maxScore: 10, step: 0.25, required: true, isScored: true, isParent: false }, item); });
  }
  function readJson(key) { try { return JSON.parse(localStorage.getItem(key) || '{}'); } catch (e) { return {}; } }
  function defaultAssignments() {
    return {
      contestants: { 1: seededContestants.map(function (x) { return x.id; }), 2: [], 3: [] },
      judges: { 1: seededJudges.map(function (x) { return { judgeId: x.id, roundId: 1, required: true, assignmentStatus: 'assigned' }; }), 2: seededJudges.map(function (x) { return { judgeId: x.id, roundId: 2, required: true, assignmentStatus: 'assigned' }; }), 3: seededJudges.map(function (x) { return { judgeId: x.id, roundId: 3, required: true, assignmentStatus: 'assigned' }; }) }
    };
  }
  var saved = readJson(STORAGE_KEY); var legacyMaster = readJson('kreenAdminMasterData'); var defaults = defaultAssignments();
  var state = {
    schemaVersion: SCHEMA_VERSION,
    contestants: Array.isArray(saved.contestants) ? saved.contestants : (Array.isArray(legacyMaster.contestants) ? legacyMaster.contestants : seededContestants),
    judges: Array.isArray(saved.judges) ? saved.judges : (Array.isArray(legacyMaster.judges) ? legacyMaster.judges : seededJudges),
    contestantAssignments: saved.contestantAssignments || defaults.contestants,
    judgeAssignments: saved.judgeAssignments || defaults.judges,
    criteriaByRound: saved.criteriaByRound || { 1: seedCriteria(1), 2: seedCriteria(2), 3: seedCriteria(3) },
    reopensByRound: saved.reopensByRound || {},
    submissionOverridesByRound: saved.submissionOverridesByRound || {},
    roundStatusById: saved.roundStatusById || {},
    auditEvents: saved.auditEvents || [],
    resultSnapshotByRound: saved.resultSnapshotByRound || {},
    resultVisibilityByRound: saved.resultVisibilityByRound || {},
    tieAcknowledgementByRound: saved.tieAcknowledgementByRound || {},
    advancementBySource: saved.advancementBySource || {},
    advancementHistory: saved.advancementHistory || [],
    eventSettings: Object.assign({}, DEFAULT_EVENT_SETTINGS, saved.eventSettings || {})
  };
  // Repair blank and old relative seed paths without replacing custom photos or an explicit removal.
  if (Number(saved.schemaVersion || 0) < SCHEMA_VERSION) {
    state.contestants.forEach(function (item) {
      var seedPhoto = getSeedContestantPhoto(item);
      if (seedPhoto && (!item.photo || item.photo.indexOf('../assets/images/') === 0 || item.photo.indexOf('photos/contestant-') === 0)) item.photo = seedPhoto;
    });
  }
  DATA.rounds.forEach(function (round) { if (state.roundStatusById[round.id]) round.status = state.roundStatusById[round.id]; });
  Object.keys(state.judgeAssignments).forEach(function (roundId) {
    state.judgeAssignments[roundId] = state.judgeAssignments[roundId].map(function (assignment) { return Object.assign({}, assignment, { roundId: Number(roundId), assignmentStatus: assignment.assignmentStatus || assignment.status || 'assigned' }); });
  });
  function save() { try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); return true; } catch (e) { return false; } }
  function getEventSettings() { return Object.assign({}, state.eventSettings); }
  function setEventSettings(settings) {
    var next = Object.assign({}, DEFAULT_EVENT_SETTINGS);
    Object.keys(next).forEach(function (key) { if (Object.prototype.hasOwnProperty.call(settings, key)) next[key] = settings[key]; });
    var previous = state.eventSettings;
    state.eventSettings = next;
    if (save()) return true;
    state.eventSettings = previous;
    return false;
  }
  function resetEventSettings() { return setEventSettings(DEFAULT_EVENT_SETTINGS); }
  if (save() && Object.keys(legacyMaster).length) { try { localStorage.removeItem('kreenAdminMasterData'); } catch (e) {} }
  function getRound(id) { return DATA.getRoundById(id); }
  function getContestants() { return state.contestants.slice(); }
  function getJudges() { return state.judges.slice(); }
  function saveMasterRecord(kind, record) {
    if (kind !== 'contestants' && kind !== 'judges') return null;
    var list = state[kind]; var index = list.findIndex(function (item) { return Number(item.id) === Number(record.id); });
    if (index < 0) list.push(record); else list[index] = record;
    save(); return record;
  }
  function getRoundContestants(roundId) {
    var ids = state.contestantAssignments[Number(roundId)] || [];
    return state.contestants.filter(function (item) { return ids.indexOf(Number(item.id)) !== -1; });
  }
  function setContestantAssignment(roundId, contestantId, enabled) {
    roundId = Number(roundId); contestantId = Number(contestantId);
    var ids = state.contestantAssignments[roundId] || [];
    state.contestantAssignments[roundId] = enabled ? (ids.indexOf(contestantId) < 0 ? ids.concat(contestantId) : ids) : ids.filter(function (id) { return Number(id) !== contestantId; });
    save();
  }
  function setRoundContestantAssignments(roundId, ids) { if (getRound(roundId).status !== 'draft' || getAdvancementForTarget(roundId)) return false; state.contestantAssignments[Number(roundId)] = ids.map(Number); save(); return true; }
  function getRoundJudges(roundId) {
    return (state.judgeAssignments[Number(roundId)] || []).map(function (assignment) { return Object.assign({}, assignment, { judge: state.judges.find(function (judge) { return Number(judge.id) === Number(assignment.judgeId); }) }); }).filter(function (assignment) { return assignment.judge; });
  }
  function judgePrototypeSubmission(roundId, judgeId) {
    if (Number(judgeId) !== 3) return null;
    var submission = (readJson('kreenJudgePrototype').submissionByRound || {})[Number(roundId)];
    return submission || null;
  }
  function getMonitoringJudges(roundId) {
    var assignments = getRoundJudges(roundId);
    return assignments.map(function (assignment) {
      var source = DATA.getRoundJudges(roundId).find(function (item) { return Number(item.id) === Number(assignment.judgeId); });
      if (!source && getRound(roundId).status !== 'draft') {
        var demoSubmitted = [1, 2, 6, 7].indexOf(Number(assignment.judgeId)) !== -1;
        source = { id: Number(assignment.judgeId), completed: demoSubmitted ? getRoundContestants(roundId).length : Number(assignment.judgeId) === 4 ? Math.max(0, getRoundContestants(roundId).length - 3) : 0, total: getRoundContestants(roundId).length, submissionStatus: demoSubmitted ? 'submitted' : Number(assignment.judgeId) === 4 ? 'in-progress' : 'not-started', connection: 'online', lastSync: '—' };
      }
      var own = judgePrototypeSubmission(roundId, assignment.judgeId);
      var override = (state.submissionOverridesByRound[Number(roundId)] || {})[Number(assignment.judgeId)] || {};
      var submissionStatus = source ? source.submissionStatus : 'not-started';
      if (own && (own.status === 'reopened' || own.status === 'resubmitted' || own.isSubmitted)) submissionStatus = own.status === 'resubmitted' ? 'resubmitted' : own.status === 'reopened' ? 'reopened' : 'submitted';
      else if (override.status) submissionStatus = override.status;
      if (assignment.assignmentStatus === 'excused' || assignment.assignmentStatus === 'removed') submissionStatus = assignment.assignmentStatus;
      return Object.assign({}, source || { id: assignment.judgeId, number: 'Judge ' + assignment.judge.displayNumber, name: assignment.judge.name, completed: 0, total: getRoundContestants(roundId).length, connection: 'online', lastSync: '—' }, {
        id: Number(assignment.judgeId), number: 'Judge ' + assignment.judge.displayNumber, name: assignment.judge.name,
        submissionStatus: submissionStatus, required: !!assignment.required, assignmentStatus: assignment.assignmentStatus,
        email: assignment.judge.email, phone: assignment.judge.phone,
        submittedAt: (own && own.submittedAt) || override.submittedAt || (source && source.submissionStatus === 'submitted' ? '2026-09-23T21:42:00' : null)
      });
    });
  }
  function setJudgeAssignment(roundId, judgeId, enabled) {
    roundId = Number(roundId); judgeId = Number(judgeId);
    var assignments = state.judgeAssignments[roundId] || [];
    var assignment = assignments.find(function (item) { return Number(item.judgeId) === judgeId; });
    if (!assignment && enabled) assignments.push({ judgeId: judgeId, roundId: roundId, required: !!state.eventSettings.defaultJudgeAssignmentRequired, assignmentStatus: 'assigned' });
    else if (assignment) assignment.assignmentStatus = enabled ? 'assigned' : 'unassigned';
    state.judgeAssignments[roundId] = assignments; save();
  }
  function setJudgeRequired(roundId, judgeId, required) {
    var assignment = (state.judgeAssignments[Number(roundId)] || []).find(function (item) { return Number(item.judgeId) === Number(judgeId) && item.assignmentStatus === 'assigned'; });
    if (assignment) { assignment.required = Boolean(required); save(); }
  }
  function getCriteria(roundId) { return (state.criteriaByRound[Number(roundId)] || []).map(function (item) { return Object.assign({}, item); }); }
  function setCriteria(roundId, criteria) { state.criteriaByRound[Number(roundId)] = criteria.map(function (item) { return Object.assign({}, item, { roundId: Number(roundId) }); }); save(); }
  function getEffectiveScoredWeight(criteria) {
    return (criteria || []).filter(function (item) { return item.isScored === true && item.isParent !== true; }).reduce(function (sum, item) { return sum + Number(item.weight || 0); }, 0);
  }
  function getRoundReadiness(roundId) {
    var round = getRound(roundId); if (!round) return null;
    var contestants = getRoundContestants(roundId); var assignments = getRoundJudges(roundId).filter(function (item) { return item.assignmentStatus === 'assigned'; }); var required = assignments.filter(function (item) { return item.required; });
    var activity = getMonitoringJudges(roundId);
    var submissionRows = assignments.map(function (assignment) {
      var activityItem = activity.find(function (item) { return Number(item.id) === Number(assignment.judgeId); });
      return { judgeId: Number(assignment.judgeId), status: activityItem ? activityItem.submissionStatus : 'not-started' };
    });
    var submittedIds = activity.filter(function (item) { return item.submissionStatus === 'submitted' || item.submissionStatus === 'resubmitted'; }).map(function (item) { return Number(item.id); });
    var requiredSubmitted = required.filter(function (item) { return submittedIds.indexOf(Number(item.judgeId)) !== -1; }).length;
    var submissionSummary = {
      total: submissionRows.length,
      submitted: submissionRows.filter(function (item) { return item.status === 'submitted' || item.status === 'resubmitted'; }).length,
      inProgress: submissionRows.filter(function (item) { return item.status === 'in-progress' || item.status === 'reopened'; }).length,
      notStarted: submissionRows.filter(function (item) { return item.status === 'not-started'; }).length
    };
    submissionSummary.percentage = submissionSummary.total ? Math.round(submissionSummary.submitted * 100 / submissionSummary.total) : 0;
    var criteria = getCriteria(roundId); var scoredWeight = getEffectiveScoredWeight(criteria); var weightValid = scoredWeight === 100;
    var criteriaValid = criteria.filter(function (item) { return item.isScored && !item.isParent; }).length > 0 && criteria.every(function (item) { return !item.isScored || item.isParent || !!String(item.name || '').trim() && Number(item.maxScore) > Number(item.minScore) && Number(item.step) > 0 && (!item.parentId || criteria.some(function (parent) { return String(parent.id) === String(item.parentId) && parent.isParent; })); });
    var progress = { submitted: requiredSubmitted, required: required.length, percentage: required.length ? Math.round(requiredSubmitted * 100 / required.length) : 0 };
    return {
      contestantsAssigned: contestants.length, judgesAssigned: assignments.length, requiredJudges: required.length, optionalJudges: assignments.length - required.length, submissionSummary: submissionSummary,
      requiredSubmitted: requiredSubmitted, requiredSubmissionProgress: progress, criteria: criteria,
      effectiveScoredWeight: scoredWeight, weightValid: weightValid, criteriaValid: criteriaValid, readyToClose: round.status === 'open' && required.length > 0 && requiredSubmitted === required.length,
      items: [
        { label: 'Contestants assigned', detail: contestants.length + ' contestants ready', state: contestants.length ? 'ready' : 'review' },
        { label: 'Judges assigned', detail: assignments.length + ' judges assigned', state: assignments.length ? 'ready' : 'review' },
        { label: 'Required judges', detail: required.length + ' required judges', state: required.length ? 'ready' : 'review' },
        { label: 'Criteria weight', detail: weightValid ? '100% effective scored weight' : scoredWeight + '% effective scored weight · review required', state: weightValid ? 'ready' : 'review' },
        { label: 'Required submissions', detail: requiredSubmitted + ' / ' + required.length + ' submitted', state: required.length && requiredSubmitted === required.length ? 'ready' : 'review' }
      ]
    };
  }
  function getReopens(roundId) { return state.reopensByRound[Number(roundId)] || []; }
  function addAudit(type, roundId, judgeId, reason) {
    var item = { type: type, roundId: Number(roundId), judgeId: judgeId == null ? null : Number(judgeId), reason: reason || '', at: new Date().toISOString(), actor: 'Super Admin' };
    state.auditEvents.push(item); save(); return item;
  }
  function getAuditEvents() {
    var events = state.auditEvents.slice();
    if (!events.some(function (item) { return item.type === 'submit' && item.roundId === 1 && item.judgeId === 3; })) events.push({ type: 'submit', roundId: 1, judgeId: 3, at: '2026-09-23T21:42:00', actor: 'Amanda Wijaya', reason: '', isReference: true });
    return events.sort(function (a, b) { return new Date(b.at) - new Date(a.at); });
  }
  function setSubmissionOverride(roundId, judgeId, status, submittedAt) {
    var rows = state.submissionOverridesByRound[Number(roundId)] || {};
    rows[Number(judgeId)] = Object.assign({}, rows[Number(judgeId)] || {}, { status: status, submittedAt: submittedAt || rows[Number(judgeId)] && rows[Number(judgeId)].submittedAt || null });
    state.submissionOverridesByRound[Number(roundId)] = rows;
  }
  function reopen(roundId, judgeId, reason) {
    roundId = Number(roundId); judgeId = Number(judgeId); reason = String(reason || '').trim();
    var judge = getMonitoringJudges(roundId).find(function (item) { return item.id === judgeId; });
    if (!reason || !getRound(roundId) || getRound(roundId).status !== 'open' || !judge || ['submitted', 'resubmitted'].indexOf(judge.submissionStatus) === -1) return null;
    var item = { judgeId: judgeId, roundId: roundId, reason: reason, originalSubmittedAt: judge.submittedAt, reopenedAt: new Date().toISOString(), reopenedBy: 'Super Admin', resubmittedAt: null };
    state.reopensByRound[roundId] = state.reopensByRound[roundId] || []; state.reopensByRound[roundId].push(item);
    setSubmissionOverride(roundId, judgeId, 'reopened', judge.submittedAt);
    if (judgeId === 3) { var own = readJson('kreenJudgePrototype'); own.stateVersion = 2; own.submissionByRound = own.submissionByRound || {}; var hadRealSubmission = !!(own.submissionByRound[roundId] && own.submissionByRound[roundId].isSubmitted); own.submissionByRound[roundId] = Object.assign({}, own.submissionByRound[roundId] || {}, { isSubmitted: false, status: 'reopened', reason: reason, reopenedAt: item.reopenedAt, originalSubmittedAt: judge.submittedAt, referenceSubmission: !hadRealSubmission }); try { localStorage.setItem('kreenJudgePrototype', JSON.stringify(own)); } catch (e) {} }
    addAudit('reopen', roundId, judgeId, reason); return item;
  }
  function updateJudgeAssignment(roundId, judgeId, action, reason) {
    roundId = Number(roundId); judgeId = Number(judgeId); reason = String(reason || '').trim();
    var round = getRound(roundId); var assignment = (state.judgeAssignments[roundId] || []).find(function (item) { return Number(item.judgeId) === judgeId; });
    if (!round || round.status !== 'open' || !assignment) return { ok: false, message: 'Judge governance is available only while this round is open.' };
    var judge = getMonitoringJudges(roundId).find(function (item) { return item.id === judgeId; });
    if (action === 'excuse' && assignment.assignmentStatus === 'assigned' && reason) { assignment.assignmentStatus = 'excused'; assignment.excuseReason = reason; assignment.excusedAt = new Date().toISOString(); addAudit('excuse', roundId, judgeId, reason); return { ok: true }; }
    if (action === 'restore' && assignment.assignmentStatus === 'excused') { assignment.assignmentStatus = 'assigned'; addAudit('restore', roundId, judgeId); return { ok: true }; }
    if (action === 'remove' && assignment.assignmentStatus === 'assigned') {
      if (judge && (judge.completed > 0 || ['submitted', 'resubmitted', 'reopened', 'in-progress'].indexOf(judge.submissionStatus) !== -1)) return { ok: false, message: 'This judge already has scoring activity. Use Excused or Reopen governance instead.' };
      assignment.assignmentStatus = 'removed'; addAudit('remove', roundId, judgeId); return { ok: true };
    }
    return { ok: false, message: action === 'excuse' ? 'A reason is required.' : 'This action is not available for this judge.' };
  }
  function closeRound(roundId) {
    roundId = Number(roundId); var ready = getRoundReadiness(roundId);
    if (!ready || !ready.readyToClose) return false;
    if (roundId === 1 && getEligibleResultJudges(roundId).some(function (judge) { return judge.id === 3; })) {
      var own = readJson('kreenJudgePrototype'); own.stateVersion = 2; own.submissionByRound = own.submissionByRound || {};
      if (!own.submissionByRound[roundId] || !own.submissionByRound[roundId].isSubmitted) {
        own.submissionByRound[roundId] = Object.assign({}, own.submissionByRound[roundId] || {}, { isSubmitted: true, status: 'submitted', submittedAt: '2026-09-23T21:42:00', referenceSubmission: true });
        try { localStorage.setItem('kreenJudgePrototype', JSON.stringify(own)); } catch (e) {}
      }
    }
    state.roundStatusById[roundId] = 'closed'; getRound(roundId).status = 'closed'; addAudit('close', roundId, null); return true;
  }
  function resultCriteria(roundId) {
    var keys = { 'evening-gown': 'eveningGown', 'stage-presence': 'stagePresence', 'final-question': 'finalQuestion', 'overall-impression': 'overallImpression' };
    return getCriteria(roundId).filter(function (item) { return item.isScored && !item.isParent; }).map(function (item) { return { key: keys[item.id] || item.id, name: item.name, weight: Number(item.weight) }; });
  }
  function getJudgeScoreSheet(roundId, judgeId, contestantId) {
    roundId = Number(roundId); judgeId = Number(judgeId); contestantId = Number(contestantId);
    var criteria = resultCriteria(roundId); var scores = {};
    var ownState = judgeId === 3 ? readJson('kreenJudgePrototype') : {};
    var ownSubmission = (ownState.submissionByRound || {})[roundId];
    var ownScores = ownSubmission && ownState.scoresByRound && ownState.scoresByRound[roundId] && ownState.scoresByRound[roundId][contestantId];
    var reference = {
      1: { communication: 8.75, confidence: 9, substance: 8.5, eveningGown: 9.25, stagePresence: 9 },
      2: { communication: 8.5, confidence: 8.75, substance: 8.75, eveningGown: 9, stagePresence: 8.75 }
    };
    criteria.forEach(function (item, index) {
      if (ownScores && ownScores[item.key] != null) scores[item.key] = ownScores[item.key];
      else if (ownSubmission && ownSubmission.referenceSubmission) scores[item.key] = reference[contestantId] && reference[contestantId][item.key] != null ? reference[contestantId][item.key] : 8;
      else if (ownScores) scores[item.key] = ownScores[item.key];
      else if (roundId === 1 && judgeId === 3 && reference[contestantId] && reference[contestantId][item.key] != null) scores[item.key] = reference[contestantId][item.key];
      else {
        var referenceBand = (contestantId * 13) % 15;
        var judgeShift = ((judgeId % 3) - 1) * 0.25;
        var criterionShift = (((index * 2) % 3) - 1) * 0.25;
        scores[item.key] = Math.max(1, Math.min(10, 6.25 + referenceBand * 0.25 + judgeShift + criterionShift));
      }
    });
    return { criteria: criteria, scores: scores, source: ownScores ? 'judge-state' : 'prototype-reference' };
  }
  function calculateContestantJudgeTotal(roundId, judgeId, contestantId) {
    var sheet = getJudgeScoreSheet(roundId, judgeId, contestantId);
    if (!sheet.criteria.length || sheet.criteria.some(function (item) { return sheet.scores[item.key] == null; })) return null;
    return sheet.criteria.reduce(function (sum, item) { return sum + Number(sheet.scores[item.key]) * item.weight / 10; }, 0);
  }
  function getEligibleResultJudges(roundId) {
    return getMonitoringJudges(roundId).filter(function (judge) { return judge.assignmentStatus === 'assigned' && judge.required && (judge.submissionStatus === 'submitted' || judge.submissionStatus === 'resubmitted'); });
  }
  function calculateRoundResults(roundId) {
    roundId = Number(roundId); var round = getRound(roundId);
    if (!round) return { available: false, reason: 'Round not found.' };
    if (round.status === 'finalized') {
      var frozen = state.resultSnapshotByRound[roundId];
      return frozen ? Object.assign({ available: true, finalized: true, hasTie: frozen.items.some(function (item) { return item.tied; }) }, frozen) : { available: false, reason: 'Finalized result snapshot is missing.' };
    }
    if (round.status !== 'closed') return { available: false, reason: 'Results are unavailable while judging is open. Close the round after all required judges have submitted.' };
    var ready = getRoundReadiness(roundId);
    if (!ready || !ready.requiredJudges || ready.requiredSubmitted !== ready.requiredJudges) return { available: false, reason: 'All active Required judges must submit before official results can be calculated.' };
    var eligible = getEligibleResultJudges(roundId); var contestants = getRoundContestants(roundId);
    if (!eligible.length || !contestants.length) return { available: false, reason: 'No eligible judges or contestants are available.' };
    var items = contestants.map(function (contestant) {
      var judgeScores = getMonitoringJudges(roundId).map(function (judge) {
        var included = eligible.some(function (item) { return item.id === judge.id; });
        var hasHistory = judge.completed >= contestant.number || ['submitted', 'resubmitted', 'reopened'].indexOf(judge.submissionStatus) !== -1;
        var total = hasHistory ? calculateContestantJudgeTotal(roundId, judge.id, contestant.id) : null;
        var exclusion = included ? '' : judge.assignmentStatus === 'excused' ? 'Excused — Not Counted' : judge.assignmentStatus === 'removed' ? 'Removed — Not Counted' : !judge.required ? 'Optional — Not Counted' : 'Not Submitted — Not Counted';
        return { judgeId: judge.id, judgeNumber: judge.number, judgeName: judge.name, total: total, included: included, exclusion: exclusion, assignmentStatus: judge.assignmentStatus, criteriaScores: hasHistory ? getJudgeScoreSheet(roundId, judge.id, contestant.id).scores : {} };
      });
      var counted = judgeScores.filter(function (item) { return item.included; });
      if (counted.some(function (item) { return item.total == null; })) return null;
      var average = counted.reduce(function (sum, item) { return sum + item.total; }, 0) / counted.length;
      return { contestantId: contestant.id, number: contestant.number, name: contestant.name, country: contestant.country, photo: contestant.photo || '', combinedScore: Number(average.toFixed(2)), eligibleJudgeCount: counted.length, judgeScores: judgeScores };
    });
    if (items.some(function (item) { return !item; })) return { available: false, reason: 'An eligible judge score sheet is incomplete. Official ranking cannot be calculated.' };
    items.sort(function (a, b) { return b.combinedScore - a.combinedScore || a.number - b.number; });
    items.forEach(function (item, index) {
      var previous = items[index - 1]; item.rank = previous && previous.combinedScore === item.combinedScore ? previous.rank : index + 1;
      item.tied = !!(previous && previous.combinedScore === item.combinedScore || items[index + 1] && items[index + 1].combinedScore === item.combinedScore);
    });
    return { available: true, finalized: false, roundId: roundId, eligibleJudgeIds: eligible.map(function (item) { return item.id; }), eligibleJudgeCount: eligible.length, contestantCount: contestants.length, items: items, hasTie: items.some(function (item) { return item.tied; }) };
  }
  function getRoundResultStatus(roundId) { var round = getRound(roundId); if (!round) return 'unavailable'; return round.status === 'finalized' && state.resultSnapshotByRound[Number(roundId)] ? 'finalized' : calculateRoundResults(roundId).available ? 'provisional' : 'unavailable'; }
  function getResultSnapshot(roundId) { return state.resultSnapshotByRound[Number(roundId)] || null; }
  function isResultVisible(roundId) { return getRoundResultStatus(roundId) === 'finalized' && state.resultVisibilityByRound[Number(roundId)] === true; }
  function acknowledgeTie(roundId) { var result = calculateRoundResults(roundId); if (!result.available || !result.hasTie || result.finalized) return false; state.tieAcknowledgementByRound[Number(roundId)] = true; save(); return true; }
  function isTieAcknowledged(roundId) { return state.tieAcknowledgementByRound[Number(roundId)] === true; }
  function noteResultsCalculated(roundId) {
    var result = calculateRoundResults(roundId); if (!result.available || result.finalized) return false;
    if (!state.auditEvents.some(function (item) { return item.type === 'results-calculated' && item.roundId === Number(roundId); })) addAudit('results-calculated', roundId, null);
    return true;
  }
  function finalizeResults(roundId) {
    roundId = Number(roundId); var round = getRound(roundId); var result = calculateRoundResults(roundId);
    if (!round || round.status !== 'closed' || !result.available || result.eligibleJudgeCount !== getRoundReadiness(roundId).requiredJudges || result.hasTie && !isTieAcknowledged(roundId)) return false;
    noteResultsCalculated(roundId);
    var snapshot = JSON.parse(JSON.stringify({ roundId: roundId, finalizedAt: new Date().toISOString(), finalizedBy: 'Super Admin', eligibleJudgeIds: result.eligibleJudgeIds, eligibleJudgeCount: result.eligibleJudgeCount, contestantCount: result.contestantCount, items: result.items }));
    state.resultSnapshotByRound[roundId] = snapshot;
    state.resultVisibilityByRound[roundId] = !!state.eventSettings.resultVisibilityAfterFinalization;
    state.roundStatusById[roundId] = 'finalized'; round.status = 'finalized';
    addAudit('finalize', roundId, null); return true;
  }
  function setResultVisibility(roundId, visible) {
    roundId = Number(roundId); if (getRoundResultStatus(roundId) !== 'finalized') return false;
    visible = !!visible; if (state.resultVisibilityByRound[roundId] === visible) return true;
    state.resultVisibilityByRound[roundId] = visible; addAudit(visible ? 'visibility-on' : 'visibility-off', roundId, null); return true;
  }
  function getNextRound(roundId) { var round = getRound(roundId); return round ? DATA.rounds.slice().sort(function (a, b) { return a.order - b.order; }).find(function (item) { return item.order > round.order; }) || null : null; }
  function getPreviousRound(roundId) { var round = getRound(roundId); return round ? DATA.rounds.slice().sort(function (a, b) { return b.order - a.order; }).find(function (item) { return item.order < round.order; }) || null : null; }
  function getAdvancement(roundId) { return state.advancementBySource[Number(roundId)] || null; }
  function getAdvancementForTarget(roundId) { return Object.keys(state.advancementBySource).map(function (key) { return state.advancementBySource[key]; }).find(function (item) { return item.targetRoundId === Number(roundId); }) || null; }
  function getAdvancementHistory() { return state.advancementHistory.slice(); }
  function getDefaultAdvancementIds(roundId) { var source = getRound(roundId); var result = getResultSnapshot(roundId); return source && result ? result.items.slice(0, Number(source.advancementCount || 0)).map(function (item) { return item.contestantId; }) : []; }
  function hasAdvancementCutoffTie(roundId) {
    var round = getRound(roundId); var result = getResultSnapshot(roundId); var count = round && Number(round.advancementCount);
    return !!(result && count > 0 && result.items[count] && result.items[count - 1].combinedScore === result.items[count].combinedScore);
  }
  function validateAdvancement(roundId, selectedIds, reason) {
    var source = getRound(roundId), target = getNextRound(roundId), snapshot = getResultSnapshot(roundId);
    if (!source || source.status !== 'finalized' || !snapshot || !target || target.status !== 'draft' || getAdvancement(roundId)) return { ok: false, message: 'Advancement requires finalized results and an unstarted target round.' };
    var count = Number(source.advancementCount || 0); var ids = (selectedIds || []).map(Number);
    if (!count || ids.length !== count || new Set(ids).size !== count || ids.some(function (id) { return !snapshot.items.some(function (item) { return item.contestantId === id; }); })) return { ok: false, message: 'Select exactly ' + count + ' contestants from the official result.' };
    var defaults = getDefaultAdvancementIds(roundId); var manual = ids.some(function (id) { return defaults.indexOf(id) === -1; }); var cutoffTie = hasAdvancementCutoffTie(roundId);
    if ((manual || cutoffTie) && !String(reason || '').trim()) return { ok: false, message: cutoffTie ? 'Resolve the qualification-cut tie and provide a reason.' : 'A reason is required when selection differs from the official Top ' + count + '.' };
    return { ok: true, manual: manual || cutoffTie, cutoffTie: cutoffTie, targetRoundId: target.id, count: count };
  }
  function confirmAdvancement(roundId, selectedIds, reason) {
    roundId = Number(roundId); var check = validateAdvancement(roundId, selectedIds, reason); if (!check.ok) return check;
    var snapshot = getResultSnapshot(roundId); var ids = selectedIds.map(Number);
    var record = { sourceRoundId: roundId, targetRoundId: check.targetRoundId, selectedContestantIds: ids, sourceResultSnapshotId: roundId + ':' + snapshot.finalizedAt, method: check.manual ? 'manual' : 'top_n', reason: String(reason || '').trim(), confirmedBy: 'Super Admin', confirmedAt: new Date().toISOString(), adjustments: [] };
    state.advancementBySource[roundId] = record; state.contestantAssignments[check.targetRoundId] = ids.slice(); state.advancementHistory.push({ type: 'advancement-confirmed', record: JSON.parse(JSON.stringify(record)) });
    addAudit('advancement-confirmed', roundId, null, record.reason || ids.length + ' contestants → ' + getRound(check.targetRoundId).name); return { ok: true, record: record };
  }
  function resetAdvancement(roundId, reason) {
    roundId = Number(roundId); var record = getAdvancement(roundId); reason = String(reason || '').trim();
    if (!record || !reason || getRound(record.targetRoundId).status !== 'draft') return false;
    state.contestantAssignments[record.targetRoundId] = []; delete state.advancementBySource[roundId]; state.advancementHistory.push({ type: 'advancement-reset', record: JSON.parse(JSON.stringify(record)), reason: reason, at: new Date().toISOString() });
    addAudit('advancement-reset', roundId, null, reason); return true;
  }
  function adjustAdvancementAssignment(targetRoundId, ids, reason) {
    targetRoundId = Number(targetRoundId); var record = getAdvancementForTarget(targetRoundId); reason = String(reason || '').trim();
    if (!record || getRound(targetRoundId).status !== 'draft' || !reason) return false;
    ids = ids.map(Number); if (new Set(ids).size !== ids.length || ids.some(function (id) { return !getContestants().some(function (item) { return item.id === id; }); })) return false;
    state.contestantAssignments[targetRoundId] = ids.slice(); record.adjustments.push({ contestantIds: ids.slice(), reason: reason, at: new Date().toISOString(), by: 'Super Admin' });
    state.advancementHistory.push({ type: 'advancement-adjusted', sourceRoundId: record.sourceRoundId, targetRoundId: targetRoundId, contestantIds: ids.slice(), reason: reason, at: new Date().toISOString() });
    addAudit('advancement-adjusted', record.sourceRoundId, null, reason); return true;
  }
  function copyRoundConfiguration(sourceRoundId, targetRoundId, copyJudges, copyCriteria) {
    sourceRoundId = Number(sourceRoundId); targetRoundId = Number(targetRoundId);
    if (!getRound(sourceRoundId) || !getRound(targetRoundId) || getRound(targetRoundId).status !== 'draft' || !getNextRound(sourceRoundId) || getNextRound(sourceRoundId).id !== targetRoundId || !copyJudges && !copyCriteria) return false;
    if (copyJudges) state.judgeAssignments[targetRoundId] = (state.judgeAssignments[sourceRoundId] || []).filter(function (item) { return item.assignmentStatus === 'assigned'; }).map(function (item) { return { judgeId: item.judgeId, roundId: targetRoundId, required: !!item.required, assignmentStatus: 'assigned' }; });
    if (copyCriteria) state.criteriaByRound[targetRoundId] = getCriteria(sourceRoundId).map(function (item) { return Object.assign({}, item, { roundId: targetRoundId }); });
    addAudit('configuration-copied', targetRoundId, null, 'From ' + getRound(sourceRoundId).name); return true;
  }
  function canOpenRound(roundId) {
    var round = getRound(roundId), previous = getPreviousRound(roundId), ready = getRoundReadiness(roundId);
    return !!(round && round.status === 'draft' && (!previous || getAdvancement(previous.id)) && ready && ready.contestantsAssigned > 0 && ready.judgesAssigned > 0 && ready.requiredJudges > 0 && ready.weightValid && ready.criteriaValid);
  }
  function openRound(roundId) { roundId = Number(roundId); if (!canOpenRound(roundId)) return false; state.roundStatusById[roundId] = 'open'; getRound(roundId).status = 'open'; addAudit('open', roundId, null); return true; }
  window.KreenAdminDomain = {
    schemaVersion: SCHEMA_VERSION, storageKey: STORAGE_KEY, getEventSettings: getEventSettings, setEventSettings: setEventSettings, resetEventSettings: resetEventSettings,
    getRound: getRound, getContestants: getContestants, getSeedContestantPhoto: getSeedContestantPhoto, getJudges: getJudges,
    saveMasterRecord: saveMasterRecord, getRoundContestants: getRoundContestants, setContestantAssignment: setContestantAssignment,
    setRoundContestantAssignments: setRoundContestantAssignments, getRoundJudges: getRoundJudges, setJudgeAssignment: setJudgeAssignment,
    setJudgeRequired: setJudgeRequired, getCriteria: getCriteria, setCriteria: setCriteria,
    getEffectiveScoredWeight: getEffectiveScoredWeight, getRoundReadiness: getRoundReadiness, getMonitoringJudges: getMonitoringJudges,
    getReopens: getReopens, reopen: reopen, updateJudgeAssignment: updateJudgeAssignment, closeRound: closeRound, getAuditEvents: getAuditEvents,
    getJudgeScoreSheet: getJudgeScoreSheet, calculateContestantJudgeTotal: calculateContestantJudgeTotal,
    getEligibleResultJudges: getEligibleResultJudges, calculateRoundResults: calculateRoundResults, getRoundResultStatus: getRoundResultStatus,
    getResultSnapshot: getResultSnapshot, isResultVisible: isResultVisible, acknowledgeTie: acknowledgeTie, isTieAcknowledged: isTieAcknowledged,
    noteResultsCalculated: noteResultsCalculated, finalizeResults: finalizeResults, setResultVisibility: setResultVisibility,
    getNextRound: getNextRound, getPreviousRound: getPreviousRound, getAdvancement: getAdvancement, getAdvancementForTarget: getAdvancementForTarget, getAdvancementHistory: getAdvancementHistory,
    getDefaultAdvancementIds: getDefaultAdvancementIds, hasAdvancementCutoffTie: hasAdvancementCutoffTie, validateAdvancement: validateAdvancement, confirmAdvancement: confirmAdvancement,
    resetAdvancement: resetAdvancement, adjustAdvancementAssignment: adjustAdvancementAssignment, copyRoundConfiguration: copyRoundConfiguration, canOpenRound: canOpenRound, openRound: openRound
  };
})();
