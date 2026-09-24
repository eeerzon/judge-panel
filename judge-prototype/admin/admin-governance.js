// Phase 4C operational demo: local-only Admin governance UI.
(function () {
  var app = document.querySelector('.admin-app');
  if (!app) return;
  var page = app.dataset.adminPage;
  if (['round', 'monitoring', 'live', 'submission', 'audit'].indexOf(page) === -1) return;
  var DATA = window.KreenAdminData;
  var D = window.KreenAdminDomain;
  var params = new URLSearchParams(location.search);
  var roundId = Number(params.get(page === 'round' ? 'id' : 'round') || 1);
  var round = DATA.getRoundById(roundId);
  var root = document.getElementById('admin-page-content');
  var filter = 'all';
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>'"]/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[c]; }); }
  function time(value) { if (!value) return '—'; var date = new Date(value); return Number.isNaN(date.getTime()) ? esc(value) : String(date.getHours()).padStart(2, '0') + ':' + String(date.getMinutes()).padStart(2, '0'); }
  function badge(value) { var names = { 'not-started': 'Not Started', 'in-progress': 'In Progress', submitted: 'Submitted', reopened: 'Reopened', resubmitted: 'Resubmitted', excused: 'Excused', removed: 'Removed', closed: 'Closed', open: 'Open', draft: 'Draft' }; return '<span class="admin-status admin-status-' + esc(value) + '"><span class="admin-status-dot"></span>' + esc(names[value] || value) + '</span>'; }
  function panel(title, content) { return '<section class="admin-panel admin-governance-panel"><h3>' + esc(title) + '</h3>' + content + '</section>'; }
  function workspace(tab, title, description) { return window.renderRoundWorkspace({ roundId: roundId, activeTab: tab, pageTitle: title, pageDescription: description, contentTarget: 'admin-page-content' }); }
  function monitoringUrl() { return 'monitoring.html?round=' + roundId; }
  function submissionUrl(judgeId) { return 'submission-detail.html?round=' + roundId + '&judge=' + judgeId; }
  function findJudge(id) { return D.getMonitoringJudges(roundId).find(function (item) { return item.id === Number(id); }); }
  function renderRound() {
    if (!round) return;
    var slot = workspace('overview', 'Overview', 'Round readiness and judging progress.');
    var ready = D.getRoundReadiness(roundId);
    var missing = ready.requiredJudges - ready.requiredSubmitted;
    var closed = round.status === 'closed';
    var finalized = round.status === 'finalized';
    slot.innerHTML = '<section class="admin-stat-grid"><article class="admin-stat-card"><span class="admin-stat-value">' + badge(round.status) + '</span><span class="admin-stat-label">Round status</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + ready.requiredSubmitted + ' / ' + ready.requiredJudges + '</span><span class="admin-stat-label">Required submitted</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + ready.optionalJudges + '</span><span class="admin-stat-label">Optional judges</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + ready.contestantsAssigned + '</span><span class="admin-stat-label">Contestants assigned</span></article></section>' +
      '<div class="admin-governance-grid">' + panel('Judging readiness', '<div class="admin-governance-check">' + (ready.contestantsAssigned ? '✓' : '○') + ' ' + ready.contestantsAssigned + ' contestants assigned</div><div class="admin-governance-check">' + (ready.judgesAssigned ? '✓' : '○') + ' ' + ready.judgesAssigned + ' judges assigned</div><div class="admin-governance-check">' + (ready.weightValid ? '✓' : '○') + ' Criteria weight = ' + ready.effectiveScoredWeight + '%</div>') +
      panel('Submission readiness', '<div class="admin-governance-check">' + ready.requiredSubmitted + ' / ' + ready.requiredJudges + ' required judges submitted</div><div class="admin-governance-check">' + ready.optionalJudges + ' optional judges do not block closing</div><p class="admin-governance-verdict ' + (ready.readyToClose ? 'is-ready' : '') + '">' + (finalized ? 'Results finalized · scoring and configuration are locked' : closed ? 'Round closed · scoring is read-only' : ready.readyToClose ? '✓ Ready to close' : missing > 0 ? missing + ' required judge' + (missing === 1 ? '' : 's') + ' still need attention' : 'Round is not ready to close') + '</p>') + '</div>' +
      '<div class="admin-section-heading"><div><h2>Round actions</h2><p>' + (finalized ? 'Official result snapshot is locked.' : closed ? 'Review provisional results before finalization.' : 'Only required active judges block Close Round.') + '</p></div></div>' +
      (finalized ? '<p class="admin-lock-note">Official Results Ready · <a href="round-results.html?round=' + roundId + '">View Results</a></p>' : closed ? '<p class="admin-lock-note">This round is closed. <a href="round-results.html?round=' + roundId + '">Review provisional results</a></p>' : ready.readyToClose ? '<button class="admin-btn admin-btn-danger" type="button" data-governance="close">Close Round</button>' : '<div class="admin-warning"><strong>Cannot close round yet.</strong> ' + (missing > 0 ? missing + ' required judge' + (missing === 1 ? ' has' : 's have') + ' not submitted.' : 'The round is not open or has no required judges.') + ' <a href="' + monitoringUrl() + '">View Live Monitoring</a></div>');
    slot.insertAdjacentHTML('beforeend', '<p class="admin-muted admin-lifecycle-note">Lifecycle: Draft → Open → Closed → Finalized</p>');
    if (round.status === 'draft') {
      var previous = D.getPreviousRound(roundId); var advancement = D.getAdvancementForTarget(roundId); var canOpen = D.canOpenRound(roundId);
      slot.insertAdjacentHTML('beforeend', '<section class="admin-panel admin-governance-panel"><p class="admin-eyebrow">Next round setup</p><h3>' + esc(round.name) + ' readiness</h3><div class="admin-governance-check">' + (advancement ? '✓ ' + advancement.selectedContestantIds.length + ' contestants advanced from ' + esc(previous.name) : '○ Advancement from previous round pending') + '</div><div class="admin-governance-check">' + (ready.judgesAssigned && ready.requiredJudges ? '✓' : '○') + ' ' + ready.judgesAssigned + ' judges · ' + ready.requiredJudges + ' Required</div><div class="admin-governance-check">' + (ready.weightValid ? '✓' : '○') + ' Criteria ' + ready.effectiveScoredWeight + '% effective weight</div><div class="admin-page-actions"><a class="admin-btn" href="round-contestants.html?round=' + roundId + '">Configure Round</a>' + (previous && advancement ? '<button class="admin-btn" data-progression-copy>Copy Configuration from ' + esc(previous.name) + '</button>' : '') + '<button class="admin-btn admin-btn-primary" data-progression-open ' + (canOpen ? '' : 'disabled title="Complete advancement and round readiness first"') + '>Open ' + esc(round.name) + '</button></div></section>');
    }
  }
  function progressionModal(kind) {
    var previous = D.getPreviousRound(roundId), ready = D.getRoundReadiness(roundId), modal = document.createElement('div'); modal.id = 'progression-modal'; modal.className = 'admin-modal-backdrop'; modal.dataset.kind = kind;
    modal.innerHTML = kind === 'copy' ? '<section class="admin-modal" role="dialog" aria-modal="true"><h2>Copy configuration from ' + esc(previous.name) + '?</h2><p>Contestants are not copied. The target gets independent configuration.</p><label class="admin-required-toggle"><input type="checkbox" id="copy-judges" checked> Judge assignments and Required flags</label><label class="admin-required-toggle"><input type="checkbox" id="copy-criteria" checked> Criteria hierarchy and scoring rules</label><div class="admin-modal-actions"><button class="admin-btn" data-progression-cancel>Cancel</button><button class="admin-btn admin-btn-primary" data-progression-confirm>Copy Configuration</button></div></section>' : '<section class="admin-modal" role="dialog" aria-modal="true"><h2>Open ' + esc(round.name) + '?</h2><p>' + ready.contestantsAssigned + ' contestants · ' + ready.judgesAssigned + ' judges · ' + ready.effectiveScoredWeight + '% scoring weight. Judges will be able to begin scoring.</p><div class="admin-modal-actions"><button class="admin-btn" data-progression-cancel>Cancel</button><button class="admin-btn admin-btn-primary" data-progression-confirm>Open Round</button></div></section>';
    document.body.appendChild(modal); modal.querySelector('[data-progression-cancel]').focus();
  }
  function needsAttention(judge) { return judge.assignmentStatus === 'assigned' && judge.required && (['not-started', 'in-progress', 'reopened'].indexOf(judge.submissionStatus) !== -1 || judge.connection === 'offline'); }
  function renderMonitoring() {
    if (!round) return;
    var slot = workspace('monitoring', 'Monitoring', 'Submission and connection status for this round.');
    var ready = D.getRoundReadiness(roundId);
    slot.innerHTML = '<section class="admin-stat-grid"><article class="admin-stat-card"><span class="admin-stat-value">' + ready.judgesAssigned + '</span><span class="admin-stat-label">Assigned judges</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + ready.requiredSubmitted + ' / ' + ready.requiredJudges + '</span><span class="admin-stat-label">Required submitted</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + ready.optionalJudges + '</span><span class="admin-stat-label">Optional judges</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + D.getMonitoringJudges(roundId).filter(needsAttention).length + '</span><span class="admin-stat-label">Needs attention</span></article></section>' +
      (round.status === 'closed' || round.status === 'finalized' ? '<p class="admin-lock-note">Round ' + esc(round.status) + ' · monitoring is read-only.</p>' : '') +
      '<div class="admin-filter-bar"><div class="admin-search-wrap"><span class="admin-search-icon" aria-hidden="true">⌕</span><label class="sr-only" for="judge-search">Search judges</label><input class="admin-field" id="judge-search" type="search" placeholder="Search judge number or name"></div><button class="admin-filter-pill is-active" data-monitor-filter="all">All</button><button class="admin-filter-pill" data-monitor-filter="attention">Needs Attention</button><button class="admin-filter-pill" data-monitor-filter="submitted">Submitted</button><button class="admin-filter-pill" data-monitor-filter="excused">Excused</button></div>' +
      '<section class="admin-panel admin-data-list" aria-label="Judge monitoring"><div class="admin-monitoring-head"><span>Judge</span><span>Progress</span><span>Submission</span><span>Connection</span><span>Last sync</span><span>Action</span></div><div id="monitoring-rows"></div></section>';
    document.getElementById('judge-search').addEventListener('input', renderRows);
    renderRows();
  }
  function renderRows() {
    var target = document.getElementById('monitoring-rows'); if (!target) return;
    var term = (document.getElementById('judge-search').value || '').toLowerCase();
    var rows = D.getMonitoringJudges(roundId).filter(function (judge) {
      return (filter === 'all' || filter === 'attention' && needsAttention(judge) || filter === 'submitted' && ['submitted', 'resubmitted'].indexOf(judge.submissionStatus) !== -1 || filter === 'excused' && judge.submissionStatus === 'excused') && (judge.name + ' ' + judge.number).toLowerCase().indexOf(term) !== -1;
    });
    target.innerHTML = rows.length ? rows.map(function (judge) {
      var connection = judge.connection === 'offline' ? 'Offline' : judge.connection === 'syncing' ? 'Syncing' : 'Synced';
      return '<article class="admin-monitoring-row"><div class="admin-data-primary"><div class="admin-data-name">' + esc(judge.name) + '</div><div class="admin-data-subtext">' + esc(judge.number) + ' · ' + (judge.required ? 'Required' : 'Optional') + '</div></div><div class="admin-data-meta">' + judge.completed + ' / ' + judge.total + ' contestants</div>' + badge(judge.submissionStatus) + '<span class="admin-connection ' + (judge.connection === 'offline' ? 'is-offline' : judge.connection === 'syncing' ? 'is-syncing' : '') + '">' + connection + '</span><span class="admin-last-sync">' + esc(judge.lastSync) + '</span><div class="admin-row-actions"><button class="admin-btn admin-btn-small" data-judge-detail="' + judge.id + '">View</button></div></article>';
    }).join('') : '<div class="admin-state"><h3>No judges found</h3><p>Try another filter or search.</p></div>';
  }
  function showDrawer(judgeId) {
    var judge = findJudge(judgeId); if (!judge) return;
    var drawer = document.getElementById('admin-drawer'); if (!drawer) return;
    var history = D.getReopens(roundId).filter(function (item) { return item.judgeId === judge.id; });
    var last = history[history.length - 1];
    document.getElementById('admin-drawer-title').textContent = judge.name;
    document.getElementById('admin-drawer-body').innerHTML = '<div class="admin-detail-grid"><div class="admin-detail-item"><span class="admin-detail-label">Judge</span><span class="admin-detail-value">' + esc(judge.number) + ' · ' + (judge.required ? 'Required' : 'Optional') + '</span></div><div class="admin-detail-item"><span class="admin-detail-label">Round</span><span class="admin-detail-value">' + esc(round.name) + '</span></div><div class="admin-detail-item"><span class="admin-detail-label">Progress</span><span class="admin-detail-value">' + judge.completed + ' / ' + judge.total + ' contestants</span></div><div class="admin-detail-item"><span class="admin-detail-label">Submission</span><span class="admin-detail-value">' + badge(judge.submissionStatus) + '</span></div><div class="admin-detail-item"><span class="admin-detail-label">Connection</span><span class="admin-detail-value">' + (judge.connection === 'offline' ? 'Offline' : judge.connection === 'syncing' ? 'Syncing' : 'Synced') + ' · ' + esc(judge.lastSync) + '</span></div>' + (last ? '<div class="admin-detail-item"><span class="admin-detail-label">Reopened by / at</span><span class="admin-detail-value">' + esc(last.reopenedBy) + ' · ' + time(last.reopenedAt) + '</span><small>' + esc(last.reason) + '</small></div>' : '') + (judge.assignmentStatus === 'excused' ? '<div class="admin-detail-item"><span class="admin-detail-label">Excuse reason</span><span class="admin-detail-value">' + esc((D.getRoundJudges(roundId).find(function (item) { return item.judgeId === judge.id; }) || {}).excuseReason || '—') + '</span></div>' : '') + '</div>' + (judge.assignmentStatus === 'assigned' && judge.completed > 0 ? '<p class="admin-lock-note">This judge already has scoring activity. Use Excused or Reopen governance instead of Remove Assignment.</p>' : '');
    var actions = '<button class="admin-btn" data-close-drawer>Close</button>';
    if (judge.submissionStatus !== 'removed' && (judge.completed > 0 || ['submitted', 'resubmitted', 'reopened'].indexOf(judge.submissionStatus) !== -1)) actions += '<a class="admin-btn" href="' + submissionUrl(judge.id) + '">' + (judge.submissionStatus === 'in-progress' ? 'View Progress' : 'View Submission') + '</a>';
    if (round.status === 'open') {
      if (['submitted', 'resubmitted'].indexOf(judge.submissionStatus) !== -1) actions += '<button class="admin-btn admin-btn-danger" data-governance="reopen" data-judge="' + judge.id + '">Reopen Submission</button>';
      if (judge.assignmentStatus === 'assigned') actions += '<button class="admin-btn" data-governance="excuse" data-judge="' + judge.id + '">Mark Excused</button>';
      if (judge.submissionStatus === 'not-started' && judge.assignmentStatus === 'assigned') actions += '<button class="admin-btn" data-governance="remove" data-judge="' + judge.id + '">Remove Assignment</button>';
      if (judge.assignmentStatus === 'excused') actions += '<button class="admin-btn" data-governance="restore" data-judge="' + judge.id + '">Restore Judge</button>';
    }
    document.getElementById('admin-drawer-footer').innerHTML = actions;
    drawer.hidden = false;
  }
  function confirmation(action, judgeId) {
    var judge = judgeId ? findJudge(judgeId) : null;
    var titles = { close: 'Close ' + (round ? round.name : 'round') + '?', reopen: 'Reopen ' + (judge ? judge.name : 'judge') + "'s submission?", excuse: 'Mark ' + (judge ? judge.number : 'judge') + ' as excused?', remove: 'Remove ' + (judge ? judge.number : 'judge') + ' from this round?', restore: 'Restore ' + (judge ? judge.number : 'judge') + '?' };
    var copy = { close: 'All required judges have submitted. Scoring will become read-only.', reopen: 'The judge will be able to edit scores again.', excuse: 'This judge will no longer be required to submit for this round.', remove: 'Only a judge without scoring activity can be removed.', restore: 'This judge can access the round again with the previous Required/Optional setting.' };
    var modal = document.getElementById('governance-modal');
    if (!modal) { modal = document.createElement('div'); modal.id = 'governance-modal'; modal.className = 'admin-modal-backdrop'; document.body.appendChild(modal); }
    modal.dataset.action = action; modal.dataset.judge = judgeId || '';
    modal.innerHTML = '<section class="admin-modal" role="dialog" aria-modal="true" aria-labelledby="governance-title"><h2 id="governance-title">' + esc(titles[action]) + '</h2><p>' + esc(copy[action]) + '</p>' + (action === 'reopen' || action === 'excuse' ? '<label class="admin-field-label admin-governance-reason" for="governance-reason">Reason *</label><textarea class="admin-field admin-textarea" id="governance-reason" required></textarea><p class="admin-field-error" id="governance-error" hidden>Reason is required.</p>' : '') + '<div class="admin-modal-actions"><button class="admin-btn" data-governance-cancel>Cancel</button><button class="admin-btn admin-btn-danger" data-governance-confirm>' + esc(({ close: 'Close Round', reopen: 'Reopen Submission', excuse: 'Mark Excused', remove: 'Remove Assignment', restore: 'Restore Judge' })[action]) + '</button></div></section>';
    modal.hidden = false;
    var field = document.getElementById('governance-reason'); if (field) field.focus(); else modal.querySelector('[data-governance-cancel]').focus();
  }
  function confirmAction() {
    var modal = document.getElementById('governance-modal'); if (!modal) return;
    var action = modal.dataset.action; var judgeId = Number(modal.dataset.judge); var field = document.getElementById('governance-reason'); var reason = field ? field.value.trim() : '';
    if (field && !reason) { field.classList.add('is-error'); document.getElementById('governance-error').hidden = false; field.focus(); return; }
    var result = action === 'close' ? { ok: D.closeRound(roundId) } : action === 'reopen' ? { ok: !!D.reopen(roundId, judgeId, reason) } : D.updateJudgeAssignment(roundId, judgeId, action, reason);
    if (!result.ok) { modal.querySelector('.admin-modal p').textContent = result.message || 'This action is not available now. Refresh and check round readiness.'; return; }
    location.reload();
  }
  function scoreDetail(judge, contestant) {
    var sheet = D.getJudgeScoreSheet(roundId, judge.id, contestant.id);
    var total = judge.completed >= contestant.number || ['submitted', 'resubmitted', 'reopened'].indexOf(judge.submissionStatus) !== -1 ? D.calculateContestantJudgeTotal(roundId, judge.id, contestant.id) : null;
    return '<details class="admin-submission-row"><summary><span><strong>#' + String(contestant.number).padStart(2, '0') + ' ' + esc(contestant.name) + '</strong><small>' + esc(contestant.country) + '</small></span><span>Total Score <strong>' + (total == null ? '—' : total.toFixed(2)) + '</strong></span></summary><div class="admin-score-detail">' + sheet.criteria.map(function (item) { return '<div><span>' + esc(item.name) + '</span><strong>' + (total == null || sheet.scores[item.key] == null ? '—' : Number(sheet.scores[item.key]).toFixed(2)) + '</strong></div>'; }).join('') + '<div class="admin-score-total"><span>TOTAL</span><strong>' + (total == null ? '—' : total.toFixed(2) + ' / 100') + '</strong></div></div></details>';
  }
  function renderSubmission() {
    var judge = findJudge(params.get('judge')); if (!round || !judge) { root.innerHTML = panel('Submission not found', '<p>Return to Monitoring and choose a judge.</p>'); return; }
    var slot = workspace('monitoring', 'Submission Detail', 'Admin-only score and submission review.');
    var history = D.getReopens(roundId).filter(function (item) { return item.judgeId === judge.id; });
    var original = history.length && history[0].originalSubmittedAt || judge.submittedAt;
    var timeline = original ? '<div><strong>' + time(original) + '</strong>Original submission</div>' : '';
    history.forEach(function (item) { timeline += '<div><strong>' + time(item.reopenedAt) + '</strong>Reopened · ' + esc(item.reason) + '</div>'; if (item.resubmittedAt) timeline += '<div><strong>' + time(item.resubmittedAt) + '</strong>Resubmitted</div>'; });
    var contestants = D.getRoundContestants(roundId);
    slot.innerHTML = '<a class="admin-round-back" href="' + monitoringUrl() + '">← Monitoring</a><section class="admin-panel admin-governance-panel"><div class="admin-submission-heading"><div><p class="admin-eyebrow">' + esc(judge.number) + '</p><h3>' + esc(judge.name) + '</h3></div>' + badge(judge.submissionStatus) + '</div><div class="admin-submission-facts"><div><span>Round</span><strong>' + esc(round.name) + '</strong></div><div><span>Submitted at</span><strong>' + time(judge.submittedAt) + '</strong></div><div><span>Progress</span><strong>' + judge.completed + ' / ' + judge.total + ' contestants</strong></div><div><span>Connection</span><strong>' + (judge.connection === 'offline' ? 'Offline' : 'Synced') + '</strong></div></div>' + (history.length ? '<div class="admin-submission-timeline"><h4>Submission history</h4>' + timeline + '</div>' : '') + '</section><div class="admin-section-heading"><div><h2>Contestant scores</h2><p>Open a contestant to inspect criteria. Prototype reference data is used for judges without a live score sheet.</p></div></div><section class="admin-panel admin-submission-list">' + contestants.map(function (contestant) { return scoreDetail(judge, contestant); }).join('') + '</section>';
  }
  function renderLive() {
    var active = DATA.rounds.find(function (item) { return item.status === 'open'; });
    if (!active) { root.innerHTML = '<header class="admin-page-header"><div><p class="admin-eyebrow">Event operations</p><h1 class="admin-page-title">Live</h1></div></header><section class="admin-panel admin-state"><h3>No round currently open</h3><p>Review progression and open the next configured round when ready.</p><a class="admin-btn" href="rounds.html">View Rounds</a></section>'; return; }
    var ready = D.getRoundReadiness(active.id);
    root.innerHTML = '<header class="admin-page-header"><div><p class="admin-eyebrow">Event operations</p><h1 class="admin-page-title">Live</h1><p class="admin-page-description">Round operations and submission monitoring.</p></div></header><section class="admin-panel admin-live-active"><div><p class="admin-eyebrow">Current round</p><h2>' + esc(active.name) + '</h2>' + badge(active.status) + '</div><div class="admin-live-stats"><span><strong>' + ready.judgesAssigned + '</strong>Assigned</span><span><strong>' + ready.requiredSubmitted + ' / ' + ready.requiredJudges + '</strong>Required submitted</span><span><strong>' + ready.optionalJudges + '</strong>Optional</span><span><strong>' + (ready.requiredJudges - ready.requiredSubmitted) + '</strong>Needs submission</span></div><a class="admin-btn admin-btn-primary" href="monitoring.html?round=' + active.id + '">Open Monitoring</a></section><div class="admin-section-heading"><div><h2>Judge submissions</h2><p>Event-level snapshot; score detail opens inside the selected Round Workspace.</p></div></div><section class="admin-panel admin-data-list">' + D.getMonitoringJudges(active.id).map(function (judge) { return '<article class="admin-data-row"><div class="admin-data-primary"><div class="admin-data-name">' + esc(judge.name) + '</div><div class="admin-data-subtext">' + esc(judge.number) + ' · ' + (judge.required ? 'Required' : 'Optional') + '</div></div><div class="admin-data-meta">' + judge.completed + ' / ' + judge.total + ' contestants</div>' + badge(judge.submissionStatus) + '<div class="admin-row-actions"><a class="admin-btn admin-btn-small" href="submission-detail.html?round=' + active.id + '&judge=' + judge.id + '">View Submission</a></div></article>'; }).join('') + '</section>';
  }
  function renderAudit() {
    var events = D.getAuditEvents();
    root.innerHTML = '<header class="admin-page-header"><div><p class="admin-eyebrow">System</p><h1 class="admin-page-title">Audit Log</h1><p class="admin-page-description">Local prototype preview of submission and governance events.</p></div></header><div class="admin-filter-bar"><button class="admin-filter-pill is-active" data-audit-filter="all">All</button><button class="admin-filter-pill" data-audit-filter="submission">Submission</button><button class="admin-filter-pill" data-audit-filter="round">Round</button><button class="admin-filter-pill" data-audit-filter="judge">Judge</button></div><section class="admin-panel admin-audit-list" id="audit-events"></section>';
    function rows() {
      var active = document.querySelector('[data-audit-filter].is-active').dataset.auditFilter;
      var filtered = events.filter(function (item) { return active === 'all' || active === 'submission' && ['submit', 'reopen', 'resubmit'].indexOf(item.type) !== -1 || active === 'round' && ['open', 'close', 'results-calculated', 'finalize', 'visibility-on', 'visibility-off', 'advancement-confirmed', 'advancement-reset', 'advancement-adjusted', 'configuration-copied'].indexOf(item.type) !== -1 || active === 'judge' && ['excuse', 'restore', 'remove'].indexOf(item.type) !== -1; });
      document.getElementById('audit-events').innerHTML = filtered.length ? filtered.map(function (item) {
        var judge = D.getJudges().find(function (x) { return x.id === item.judgeId; }); var eventRound = DATA.getRoundById(item.roundId);
        var labels = { submit: 'submitted', reopen: 'reopened', resubmit: 'resubmitted', excuse: 'marked Excused', restore: 'restored', remove: 'removed' };
        var roundName = eventRound ? eventRound.name : 'Round';
        var roundEvents = { open: roundName + ' opened', close: roundName + ' closed', 'results-calculated': roundName + ' official results calculated', finalize: 'Super Admin finalized ' + roundName + ' results', 'visibility-on': 'Judge result visibility enabled · ' + roundName, 'visibility-off': 'Judge result visibility disabled · ' + roundName, 'advancement-confirmed': 'Super Admin confirmed advancement from ' + roundName, 'advancement-reset': 'Advancement from ' + roundName + ' reset', 'advancement-adjusted': 'Advanced contestants adjusted · ' + roundName, 'configuration-copied': 'Round configuration copied · ' + roundName };
        var description = roundEvents[item.type] || (judge ? judge.name : 'Judge') + ' ' + (labels[item.type] || item.type) + (eventRound ? ' · ' + roundName : '');
        return '<article class="admin-audit-row"><time>' + time(item.at) + '</time><div><strong>' + esc(description) + '</strong><small>' + esc(item.actor || (item.type === 'submit' || item.type === 'resubmit' ? 'Judge' : 'Super Admin')) + (item.reason ? ' · Reason: ' + esc(item.reason) : '') + '</small></div></article>';
      }).join('') : '<div class="admin-state"><h3>No events in this filter</h3><p>Governance actions and resubmissions will appear here.</p></div>';
    }
    document.querySelectorAll('[data-audit-filter]').forEach(function (button) { button.addEventListener('click', function () { document.querySelectorAll('[data-audit-filter]').forEach(function (item) { item.classList.toggle('is-active', item === button); }); rows(); }); }); rows();
  }
  document.addEventListener('click', function (event) {
    var target = event.target.closest('[data-monitor-filter], [data-judge-detail], [data-close-drawer], [data-governance], [data-governance-cancel], [data-governance-confirm], [data-progression-copy], [data-progression-open], [data-progression-cancel], [data-progression-confirm]'); if (!target) return;
    if (target.hasAttribute('data-monitor-filter')) { filter = target.dataset.monitorFilter; document.querySelectorAll('[data-monitor-filter]').forEach(function (item) { item.classList.toggle('is-active', item === target); }); renderRows(); }
    else if (target.hasAttribute('data-judge-detail')) showDrawer(target.dataset.judgeDetail);
    else if (target.hasAttribute('data-close-drawer')) document.getElementById('admin-drawer').hidden = true;
    else if (target.hasAttribute('data-governance')) confirmation(target.dataset.governance, target.dataset.judge);
    else if (target.hasAttribute('data-governance-cancel')) document.getElementById('governance-modal').hidden = true;
    else if (target.hasAttribute('data-governance-confirm')) confirmAction();
    else if (target.hasAttribute('data-progression-copy')) progressionModal('copy');
    else if (target.hasAttribute('data-progression-open') && !target.disabled) progressionModal('open');
    else if (target.hasAttribute('data-progression-cancel')) document.getElementById('progression-modal').remove();
    else if (target.hasAttribute('data-progression-confirm')) { var modal = document.getElementById('progression-modal'); var ok = modal.dataset.kind === 'open' ? D.openRound(roundId) : D.copyRoundConfiguration(D.getPreviousRound(roundId).id, roundId, document.getElementById('copy-judges').checked, document.getElementById('copy-criteria').checked); if (ok) location.reload(); }
  });
  document.addEventListener('keydown', function (event) { if (event.key === 'Escape') { var modal = document.getElementById('governance-modal'); var drawer = document.getElementById('admin-drawer'); if (modal) modal.hidden = true; if (drawer) drawer.hidden = true; } });
  if (!round && ['round', 'monitoring', 'submission'].indexOf(page) !== -1) { root.innerHTML = panel('Round not found', '<p>Choose a valid round from <a href="rounds.html">Rounds</a>.</p>'); return; }
  if (page === 'round') renderRound();
  if (page === 'monitoring') renderMonitoring();
  if (page === 'submission') renderSubmission();
  if (page === 'live') renderLive();
  if (page === 'audit') renderAudit();
})();
