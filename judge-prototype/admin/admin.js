// Admin page controllers. Shared shell and round context are rendered elsewhere.
(function () {
  var app = document.querySelector('.admin-app');
  var data = window.KreenAdminData;
  var domain = window.KreenAdminDomain;
  var modal = document.getElementById('admin-modal');
  var drawer = document.getElementById('admin-drawer');
  function query(name) { return new URLSearchParams(window.location.search).get(name); }
  function hide(element, value) { if (element) element.hidden = value; }
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>\'"]/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[c]; }); }
  function status(value) { var label = ({ open: 'Open', draft: 'Draft', closed: 'Closed', finalized: 'Finalized', submitted: 'Submitted', resubmitted: 'Resubmitted', reopened: 'Reopened', excused: 'Excused', removed: 'Removed', 'in-progress': 'In Progress', 'not-started': 'Not Started' })[value] || value; return '<span class="admin-status admin-status-' + esc(value) + '"><span class="admin-status-dot"></span>' + esc(label) + '</span>'; }
  function summary(round) { return readiness(round.id).submissionSummary; }
  function readiness(roundId) { return domain ? domain.getRoundReadiness(roundId) : null; }
  function roundCard(round) {
    var progress = summary(round); var ready = readiness(round.id);
    var resultStatus = domain ? domain.getRoundResultStatus(round.id) : 'unavailable';
    var snapshot = resultStatus === 'finalized' ? domain.getResultSnapshot(round.id) : null;
    var advancement = domain && domain.getAdvancement(round.id); var incoming = domain && domain.getAdvancementForTarget(round.id);
    var note = advancement ? advancement.selectedContestantIds.length + ' advanced to ' + esc(domain.getNextRound(round.id).name) : snapshot ? 'Official Results Ready' : incoming ? 'Advanced from ' + esc(domain.getRound(incoming.sourceRoundId).name) : round.status === 'draft' && domain.getPreviousRound(round.id) ? (domain.getPreviousRound(round.id).advancementCount || 0) + ' expected from previous round' : '';
    return '<article class="admin-round-card"><div class="admin-round-top"><div><span class="admin-round-order">' + String(round.order).padStart(2, '0') + ' · ROUND</span><h2 class="admin-round-title">' + esc(round.name) + '</h2></div>' + status(round.status) + '</div><div class="admin-round-meta"><span class="admin-round-meta-item"><strong>' + (ready ? ready.contestantsAssigned : round.contestants) + '</strong>Contestants</span><span class="admin-round-meta-item"><strong>' + (snapshot ? snapshot.eligibleJudgeCount : ready ? ready.judgesAssigned : round.judges) + '</strong>' + (snapshot ? 'Eligible Judges' : 'Judges') + '</span><span class="admin-round-meta-item"><strong>' + ready.criteria.filter(function (item) { return item.isScored && !item.isParent; }).length + '</strong>Criteria</span><span class="admin-round-meta-item"><strong>' + progress.submitted + ' / ' + progress.total + '</strong>Submitted</span></div>' + (note ? '<p class="admin-result-card-note">' + note + '</p>' : '') + '<a class="admin-btn ' + (round.status === 'open' || snapshot ? 'admin-btn-primary' : '') + '" href="' + (snapshot ? 'round-results.html?round=' : 'round.html?id=') + round.id + '">' + (snapshot ? 'View Results' : round.status === 'open' ? 'Open Round' : round.status === 'closed' ? 'View Round' : 'View Setup') + '</a></article>';
  }
  function stateMarkup(type, title, description) { return '<section class="admin-panel admin-state admin-state-' + type + '"><span class="admin-state-icon">○</span><h3>' + esc(title) + '</h3><p>' + esc(description) + '</p></section>'; }
  function renderOverview() {
    var stats = document.getElementById('overview-stats'); var cards = document.getElementById('overview-rounds'); var preview = document.getElementById('overview-monitoring');
    if (!stats || !cards || !preview) return;
    var active = data.rounds.find(function (round) { return round.status === 'open'; }) || data.rounds.find(function (round) { return round.status === 'draft' && domain.getAdvancementForTarget(round.id); }) || data.rounds.find(function (round) { return round.status !== 'finalized'; }) || data.rounds[data.rounds.length - 1]; var progress = summary(active); var state = readiness(active.id); var previous = domain.getPreviousRound(active.id), next = domain.getNextRound(active.id);
    stats.innerHTML = '<article class="admin-stat-card"><span class="admin-stat-value">' + esc(active.name) + '</span><span class="admin-stat-label">Current stage · ' + esc(active.status) + '</span><span class="admin-stat-note">' + (previous ? 'Previous: ' + esc(previous.name) + ' · ' + esc(previous.status) : 'First round') + (next ? ' · Next: ' + esc(next.name) + ' · ' + esc(next.status) : '') + '</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + state.contestantsAssigned + '</span><span class="admin-stat-label">Contestants</span><span class="admin-stat-note">' + esc(active.name) + '</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + state.judgesAssigned + '</span><span class="admin-stat-label">Assigned Judges</span><span class="admin-stat-note">' + esc(active.name) + '</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + progress.submitted + ' / ' + progress.total + '</span><span class="admin-stat-label">Judges Submitted</span><span class="admin-stat-note"><a href="round.html?id=' + active.id + '">Open ' + esc(active.name) + ' Workspace</a></span></article>';
    cards.innerHTML = data.rounds.map(roundCard).join('');
    preview.innerHTML = domain.getMonitoringJudges(active.id).slice(2, 5).map(function (judge) { return '<article class="admin-data-row"><div class="admin-data-primary"><div class="admin-data-name">' + esc(judge.name) + '</div><div class="admin-data-subtext">' + esc(judge.number) + ' · ' + esc(active.name) + '</div></div><div class="admin-data-meta">' + judge.completed + ' / ' + judge.total + ' contestants</div>' + status(judge.submissionStatus) + '<div class="admin-row-actions"><a class="admin-btn admin-btn-small" href="live.html">View Live</a></div></article>'; }).join('');
  }
  function renderRounds() {
    var container = document.getElementById('rounds-content'); if (!container) return;
    var view = query('state');
    if (view === 'empty') { container.innerHTML = stateMarkup('empty', 'No rounds yet', 'Create a draft round when the event is ready to be configured.'); return; }
    if (view === 'loading') { container.innerHTML = '<section class="admin-round-grid" aria-label="Loading rounds"><div class="admin-skeleton admin-skeleton-card"></div><div class="admin-skeleton admin-skeleton-card"></div><div class="admin-skeleton admin-skeleton-card"></div></section>'; return; }
    if (view === 'error') { container.innerHTML = stateMarkup('error', 'Rounds could not be displayed', 'This is a prototype error state. No data was changed.'); return; }
    container.innerHTML = '<section class="admin-panel admin-progression-strip" aria-label="Event progression">' + data.rounds.slice().sort(function (a, b) { return a.order - b.order; }).map(function (round, index) { return (index ? '<span class="admin-progression-arrow" aria-hidden="true">→</span>' : '') + '<a href="round.html?id=' + round.id + '"><strong>' + String(round.order).padStart(2, '0') + ' · ' + esc(round.name) + '</strong><small>' + esc(round.status) + (domain.getAdvancement(round.id) ? ' · ' + domain.getAdvancement(round.id).selectedContestantIds.length + ' advanced' : '') + '</small></a>'; }).join('') + '</section><section class="admin-round-grid" aria-label="All rounds">' + data.rounds.map(roundCard).join('') + '</section>';
  }
  function renderRound() {
    var roundId = Number(query('id') || 1); var round = data.getRoundById(roundId); var target = document.getElementById('admin-page-content');
    if (!round || !target) { if (target) target.innerHTML = stateMarkup('error', 'Round not found', 'The round link is missing or does not point to a known prototype round.'); return; }
    var slot = window.renderRoundWorkspace({ roundId: roundId, activeTab: 'overview', pageTitle: 'Overview', pageDescription: 'Round readiness and judging progress.', contentTarget: 'admin-page-content' });
    var progress = summary(round); var ready = readiness(roundId); document.title = round.name + ' — KREEN Judging';
    slot.innerHTML = '<section class="admin-stat-grid"><article class="admin-stat-card"><span class="admin-stat-value">' + status(round.status) + '</span><span class="admin-stat-label">Round status</span><span class="admin-stat-note">' + (round.status === 'open' ? 'Judging is available' : 'Setup is not yet open') + '</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + progress.submitted + ' / ' + progress.total + '</span><span class="admin-stat-label">Judges submitted</span><span class="admin-stat-note">' + progress.percentage + '% progress</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + ready.criteria.length + '</span><span class="admin-stat-label">Criteria</span><span class="admin-stat-note">Round configuration</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + ready.contestantsAssigned + '</span><span class="admin-stat-label">Contestants</span><span class="admin-stat-note">Assigned to this round</span></article></section><section class="admin-panel admin-progress-panel"><div class="admin-section-heading"><div><h2>Judging Progress</h2><p>' + progress.submitted + ' of ' + progress.total + ' judges submitted.</p></div><span class="admin-status admin-status-' + (round.status === 'open' ? 'open' : 'draft') + '"><span class="admin-status-dot"></span>' + progress.percentage + '%</span></div><div class="admin-progress admin-progress-green" aria-label="' + progress.percentage + '% of judges submitted"><span style="width:' + progress.percentage + '%"></span></div></section><div class="admin-section-heading"><div><h2>Setup Summary</h2><p>Round readiness and configuration signals before and during operations.</p></div></div><section class="admin-readiness-list" aria-label="Round readiness">' + ready.items.map(function (item) { return '<div class="admin-readiness-row"><div><div class="admin-readiness-label">' + esc(item.label) + '</div><div class="admin-readiness-detail">' + esc(item.detail) + '</div></div><span class="admin-readiness-state ' + (item.state === 'review' ? 'is-review' : '') + '">' + (item.state === 'ready' ? 'Ready' : 'Review') + '</span></div>'; }).join('') + '</section><div class="admin-section-heading"><div><h2>Round actions</h2><p>Prototype controls only. No status is persisted.</p></div><div class="admin-page-actions"><a class="admin-btn" href="monitoring.html?round=' + round.id + '">View Monitoring</a><button class="admin-btn admin-btn-danger" type="button" data-open-modal ' + (round.status !== 'open' ? 'disabled' : '') + '>Close Round</button></div></div>';
    var modalTitle = document.getElementById('admin-modal-title'); var modalCopy = document.getElementById('admin-modal-copy');
    if (modalTitle) modalTitle.textContent = 'Close ' + round.name + '?';
    if (modalCopy) modalCopy.innerHTML = 'Judges will no longer be able to submit or edit scores.<br><br>' + progress.submitted + ' of ' + progress.total + ' judges have submitted.<br><br><strong>Warning: ' + (progress.total - progress.submitted) + ' judges have not submitted.</strong>';
    var closeButton = document.querySelector('[data-open-modal]');
    if (closeButton && progress.submitted < progress.total) { closeButton.disabled = true; closeButton.title = 'All required judges must submit before this round can close.'; }
  }
  function renderMonitoring() {
    var roundId = Number(query('round') || 1); var round = data.getRoundById(roundId); var target = document.getElementById('admin-page-content');
    if (!round || !target) { if (target) target.innerHTML = stateMarkup('error', 'Round not found', 'Choose a valid round to view its operational monitoring.'); return; }
    var slot = window.renderRoundWorkspace({ roundId: roundId, activeTab: 'monitoring', pageTitle: 'Monitoring', pageDescription: 'Live submission and connection status for this round.', contentTarget: 'admin-page-content' });
    var progress = summary(round); document.title = 'Round Monitoring — ' + round.name + ' — KREEN Judging';
    slot.innerHTML = '<section class="admin-stat-grid"><article class="admin-stat-card"><span class="admin-stat-value">' + progress.total + '</span><span class="admin-stat-label">Judges</span><span class="admin-stat-note">Assigned to ' + esc(round.name) + '</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + progress.submitted + '</span><span class="admin-stat-label">Submitted</span><span class="admin-stat-note">Submission is complete</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + progress.inProgress + '</span><span class="admin-stat-label">In progress</span><span class="admin-stat-note">One connection needs review</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + progress.notStarted + '</span><span class="admin-stat-label">Not started</span><span class="admin-stat-note">No scoring activity yet</span></article></section><div class="admin-filter-bar"><div class="admin-search-wrap"><span class="admin-search-icon" aria-hidden="true">⌕</span><label class="sr-only" for="judge-search">Search judges</label><input class="admin-field" id="judge-search" type="search" placeholder="Search judge number or name"></div><button class="admin-filter-pill is-active" type="button" data-monitor-filter="all">All</button><button class="admin-filter-pill" type="button" data-monitor-filter="attention">Needs Attention</button><button class="admin-filter-pill" type="button" data-monitor-filter="submitted">Submitted</button></div><section class="admin-panel admin-data-list" aria-label="Judge monitoring"><div class="admin-monitoring-head"><span>Judge</span><span>Progress</span><span>Submission</span><span>Connection</span><span>Last sync</span><span>Action</span></div><div id="monitoring-rows"></div></section>';
    document.getElementById('judge-search').addEventListener('input', renderMonitoringRows); renderMonitoringRows();
  }
  function renderMonitoringRows() {
    var root = document.getElementById('monitoring-rows'); var roundId = Number(query('round') || 1); var round = data.getRoundById(roundId);
    if (!root || !round) return;
    var activeFilter = document.querySelector('[data-monitor-filter].is-active'); var filter = activeFilter ? activeFilter.dataset.monitorFilter : 'all'; var term = (document.getElementById('judge-search') || {}).value || '';
    var judges = data.getRoundJudges(round.id).filter(function (judge) { var attention = judge.submissionStatus !== 'submitted' || judge.connection === 'offline'; return (filter === 'all' || (filter === 'attention' && attention) || (filter === 'submitted' && judge.submissionStatus === 'submitted')) && (judge.name + ' ' + judge.number).toLowerCase().includes(term.toLowerCase()); });
    root.innerHTML = judges.length ? judges.map(function (judge) { return '<article class="admin-monitoring-row"><div class="admin-data-primary"><div class="admin-data-name">' + esc(judge.name) + '</div><div class="admin-data-subtext">' + esc(judge.number) + '</div></div><div class="admin-data-meta">' + judge.completed + ' / ' + judge.total + ' contestants</div>' + status(judge.submissionStatus) + '<span class="admin-connection ' + (judge.connection === 'offline' ? 'is-offline' : '') + '">' + (judge.connection === 'offline' ? 'Offline' : 'Online') + '</span><span class="admin-last-sync">' + esc(judge.lastSync) + '</span><div class="admin-row-actions"><button class="admin-btn admin-btn-small" type="button" data-open-drawer data-judge-id="' + judge.id + '">View</button></div></article>'; }).join('') : stateMarkup('empty', 'No judges found', 'Try another search or monitoring filter.');
  }
  function renderLive() {
    var target = document.getElementById('live-content'); if (!target) return;
    var activeRound = data.rounds.find(function (item) { return item.status === 'open'; }) || data.rounds[0]; var state = readiness(activeRound.id); var progress = summary(activeRound);
    target.innerHTML = '<section class="admin-page-header"><div><p class="admin-eyebrow">Event operations</p><h1 class="admin-page-title">Live</h1><p class="admin-page-description">Event-level operational control across the active judging round.</p></div></section><section class="admin-panel admin-live-active"><div><p class="admin-eyebrow">Active round</p><h2>' + esc(activeRound.name) + '</h2>' + status(activeRound.status) + '</div><div class="admin-live-stats"><span><strong>' + state.judgesAssigned + '</strong>Judges</span><span><strong>' + progress.submitted + '</strong>Submitted</span><span><strong>' + progress.inProgress + '</strong>In progress</span><span><strong>' + progress.notStarted + '</strong>Not started</span></div><a class="admin-btn admin-btn-primary" href="monitoring.html?round=' + activeRound.id + '">Open ' + esc(activeRound.name) + ' Monitoring</a></section>';
  }
  function renderResults() { var target = document.getElementById('results-content'); if (target) target.innerHTML = '<header class="admin-page-header"><div><p class="admin-eyebrow">Event outcome</p><h1 class="admin-page-title">Results</h1><p class="admin-page-description">Review published event results when the results workspace is ready.</p></div></header><section class="admin-panel admin-state"><span class="admin-state-icon">≡</span><h2>Results workspace pending</h2><p>Event results will be available here when the results workspace is ready.</p></section>'; }
  function renderMonitoringDrawer(judgeId) {
    var round = data.getRoundById(Number(query('round') || 1)); var judge = round && data.getRoundJudges(round.id).find(function (item) { return item.id === Number(judgeId); });
    if (!judge || !drawer) return;
    document.getElementById('admin-drawer-title').textContent = judge.name;
    document.getElementById('admin-drawer-body').innerHTML = '<div class="admin-detail-grid"><div class="admin-detail-item"><span class="admin-detail-label">Judge</span><span class="admin-detail-value">' + esc(judge.number) + '</span></div><div class="admin-detail-item"><span class="admin-detail-label">Scoring progress</span><span class="admin-detail-value">' + judge.completed + ' / ' + judge.total + ' contestants</span></div><div class="admin-detail-item"><span class="admin-detail-label">Submission status</span><span class="admin-detail-value">' + status(judge.submissionStatus) + '</span></div><div class="admin-detail-item"><span class="admin-detail-label">Connection</span><span class="admin-detail-value">' + (judge.connection === 'offline' ? 'Offline' : 'Online') + ' · Last sync ' + esc(judge.lastSync) + '</span></div></div>';
    document.getElementById('admin-drawer-footer').innerHTML = '<button class="admin-btn" type="button" data-close-drawer>Close</button><button class="admin-btn" type="button" disabled>View Submission</button><button class="admin-btn admin-btn-danger" type="button" data-open-reopen="' + judge.id + '" ' + (judge.submissionStatus === 'submitted' ? '' : 'disabled') + '>Reopen Submission</button>';
  }
  function openReopenModal(judgeId) {
    var modalEl = document.getElementById('reopen-modal');
    if (!modalEl) {
      modalEl = document.createElement('div'); modalEl.id = 'reopen-modal'; modalEl.className = 'admin-modal-backdrop';
      modalEl.innerHTML = '<section class="admin-modal" role="dialog" aria-modal="true" aria-labelledby="reopen-modal-title"><h2 id="reopen-modal-title">Reopen submission?</h2><p id="reopen-modal-copy">The judge will be able to edit scores again.</p><label class="admin-field-label" for="reopen-reason">Reason *</label><textarea class="admin-field admin-textarea" id="reopen-reason" placeholder="Required reason"></textarea><div class="admin-modal-actions"><button class="admin-btn" type="button" data-close-reopen>Cancel</button><button class="admin-btn admin-btn-danger" type="button" data-confirm-reopen>Reopen Submission</button></div></section>';
      document.body.appendChild(modalEl);
    }
    modalEl.dataset.judgeId = judgeId;
    var judge = data.getRoundJudges(Number(query('round') || 1)).find(function (item) { return item.id === Number(judgeId); });
    document.getElementById('reopen-modal-title').textContent = 'Reopen ' + (judge ? judge.name : 'judge') + "'s submission?";
    document.getElementById('reopen-reason').value = ''; modalEl.hidden = false; document.getElementById('reopen-reason').focus();
  }
  function confirmReopen() {
    var modalEl = document.getElementById('reopen-modal'); var reasonEl = document.getElementById('reopen-reason'); var reason = reasonEl.value.trim();
    if (!reason) { reasonEl.classList.add('is-error'); return; }
    reasonEl.classList.remove('is-error'); var roundId = Number(query('round') || 1); var judgeId = Number(modalEl.dataset.judgeId); var history = {};
    try { history = JSON.parse(localStorage.getItem('kreenAdminConfiguration') || '{}'); } catch (e) {}
    history.reopensByRound = history.reopensByRound || {}; history.reopensByRound[roundId] = history.reopensByRound[roundId] || [];
    history.reopensByRound[roundId].push({ roundId: roundId, judgeId: judgeId, reason: reason, reopenedAt: new Date().toISOString(), reopenedBy: 'Super Admin' });
    localStorage.setItem('kreenAdminConfiguration', JSON.stringify(history));
    try { var state = JSON.parse(localStorage.getItem('kreenJudgePrototype') || '{}'); state.submissionByRound = state.submissionByRound || {}; state.submissionByRound[roundId] = { isSubmitted: false, status: 'reopened', reason: reason, reopenedAt: new Date().toISOString() }; localStorage.setItem('kreenJudgePrototype', JSON.stringify(state)); } catch (e) {}
    modalEl.hidden = true; hide(drawer, true); window.location.reload();
  }
  document.addEventListener('click', function (event) {
    var target = event.target.closest('button, [data-open-modal], [data-open-drawer]'); if (!target) return;
    if (target.matches('[data-close-modal]')) hide(modal, true);
    else if (target.matches('[data-open-modal]') && !target.disabled) hide(modal, false);
    else if (target.matches('[data-open-drawer]')) { renderMonitoringDrawer(target.dataset.judgeId); hide(drawer, false); }
    else if (target.matches('[data-close-drawer]')) hide(drawer, true);
    else if (target.matches('[data-open-reopen]') && !target.disabled) openReopenModal(target.dataset.openReopen);
    else if (target.matches('[data-confirm-reopen]')) confirmReopen();
    else if (target.matches('[data-close-reopen]')) hide(document.getElementById('reopen-modal'), true);
    else if (target.matches('[data-monitor-filter]')) { document.querySelectorAll('[data-monitor-filter]').forEach(function (item) { item.classList.toggle('is-active', item === target); }); renderMonitoringRows(); }
  });
  [modal, drawer].forEach(function (backdrop) { if (backdrop) backdrop.addEventListener('click', function (event) { if (event.target === backdrop) hide(backdrop, true); }); });
  document.addEventListener('keydown', function (event) { if (event.key === 'Escape') { hide(modal, true); hide(drawer, true); } });
  if (!app || !data) return;
  if (app.dataset.adminPage === 'overview') renderOverview();
  if (app.dataset.adminPage === 'rounds') renderRounds();
  if (app.dataset.adminPage === 'round') renderRound();
  if (app.dataset.adminPage === 'monitoring') renderMonitoring();
  if (app.dataset.adminPage === 'live') renderLive();
  if (app.dataset.adminPage === 'results') renderResults();
})();
