// Phase 5 Results UI. All official calculations live in admin-domain.js.
(function () {
  var app = document.querySelector('.admin-app'); if (!app) return;
  var page = app.dataset.adminPage;
  if (['results', 'round-results', 'result-detail'].indexOf(page) === -1) return;
  var DATA = window.KreenAdminData; var D = window.KreenAdminDomain;
  var params = new URLSearchParams(location.search);
  var roundId = Number(params.get('round') || 1);
  var root = document.getElementById('admin-page-content');
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>'"]/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[c]; }); }
  function badge(value) { return '<span class="admin-status admin-status-' + esc(value) + '"><span class="admin-status-dot"></span>' + esc(value.charAt(0).toUpperCase() + value.slice(1)) + '</span>'; }
  function resultUrl(id) { return 'round-results.html?round=' + id; }
  function detailUrl(id) { return 'result-detail.html?round=' + roundId + '&contestant=' + id; }
  function workspace(title, description) { return window.renderRoundWorkspace({ roundId: roundId, activeTab: 'results', pageTitle: title, pageDescription: description, contentTarget: 'admin-page-content' }); }
  function avatar(item) { return item.photo ? '<img class="admin-result-avatar" src="' + esc(item.photo) + '" alt="">' : '<span class="admin-result-avatar admin-result-avatar-fallback">#' + String(item.number).padStart(2, '0') + '</span>'; }
  function renderGlobal() {
    root.innerHTML = '<header class="admin-page-header"><div><p class="admin-eyebrow">King &amp; Queen of the Pacific</p><h1 class="admin-page-title">Results</h1><p class="admin-page-description">Event-level result status by round. No cross-round ranking is calculated.</p></div></header><section class="admin-round-grid">' + DATA.rounds.map(function (round) {
      var resultStatus = D.getRoundResultStatus(round.id); var result = resultStatus === 'unavailable' ? null : D.calculateRoundResults(round.id);
      return '<article class="admin-round-card"><div class="admin-round-top"><div><span class="admin-round-order">' + String(round.order).padStart(2, '0') + ' · ROUND</span><h2 class="admin-round-title">' + esc(round.name) + '</h2></div>' + badge(round.status) + '</div><div class="admin-round-meta"><span class="admin-round-meta-item"><strong>' + (result ? result.contestantCount : D.getRoundContestants(round.id).length) + '</strong>Contestants</span><span class="admin-round-meta-item"><strong>' + (result ? result.eligibleJudgeCount : '—') + '</strong>Eligible Judges</span></div><p class="admin-result-card-note">' + (resultStatus === 'finalized' ? 'Official Results Ready' : resultStatus === 'provisional' ? 'Provisional Admin Result' : round.status === 'open' ? 'Unavailable while judging is open' : 'No results yet') + '</p>' + (resultStatus !== 'unavailable' ? '<a class="admin-btn admin-btn-primary" href="' + resultUrl(round.id) + '">View Results</a>' : '<span class="admin-btn admin-btn-small is-disabled" aria-disabled="true">No results</span>') + '</article>';
    }).join('') + '</section>';
  }
  function summary(result, round) {
    return '<section class="admin-stat-grid"><article class="admin-stat-card"><span class="admin-stat-value">' + result.contestantCount + '</span><span class="admin-stat-label">Contestants</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + result.eligibleJudgeCount + '</span><span class="admin-stat-label">Eligible Judges</span></article><article class="admin-stat-card"><span class="admin-stat-value">100%</span><span class="admin-stat-label">Required submissions</span></article><article class="admin-stat-card"><span class="admin-stat-value">' + badge(round.status) + '</span><span class="admin-stat-label">Round status</span></article></section>';
  }
  function visibilityControl(roundId, finalized) {
    var on = D.isResultVisible(roundId);
    return '<section class="admin-panel admin-result-visibility"><div><h3>Judge Results Visibility</h3><p>When enabled, judges assigned to this round can view the official ranking and combined scores.</p><small>' + (finalized ? on ? 'Visible to judges' : 'Hidden from judges' : 'Judges can only view results after finalization.') + '</small></div><button type="button" class="admin-toggle" role="switch" aria-label="Allow Judges to View Results" aria-checked="' + on + '" data-result-visibility ' + (finalized ? '' : 'disabled') + '></button></section>';
  }
  function advancementPanel(round, finalized) {
    var next = D.getNextRound(round.id); if (!next) return finalized ? '<section class="admin-panel admin-result-visibility"><div><p class="admin-eyebrow">Final Results</p><h3>End of judging progression</h3><p>This is the final round. No further advancement is available.</p></div></section>' : '';
    var record = D.getAdvancement(round.id); var count = Number(round.advancementCount || 0);
    if (!finalized) return '<section class="admin-panel admin-result-visibility"><div><p class="admin-eyebrow">Advancement · Next Round ' + esc(next.name) + '</p><h3>Advancement unavailable</h3><p>Finalize this round before selecting contestants for the next round.</p></div></section>';
    return '<section class="admin-panel admin-result-visibility"><div><p class="admin-eyebrow">Advancement · Next Round ' + esc(next.name) + '</p><h3>' + (record ? record.selectedContestantIds.length + ' contestants advanced' : 'Qualified 0 / ' + count) + '</h3><p>' + (record ? 'Confirmed ' + new Date(record.confirmedAt).toLocaleString() + (record.method === 'manual' ? ' · Manual adjustment' : '') : 'Review the official ranking before confirming advancement.') + '</p>' + (record && record.reason ? '<small>Reason: ' + esc(record.reason) + '</small>' : '') + '</div><div class="admin-advancement-actions">' + (record ? '<a class="admin-btn admin-btn-primary" href="round.html?id=' + next.id + '">View ' + esc(next.name) + '</a>' + (next.status === 'draft' ? '<button class="admin-btn admin-btn-danger" data-advancement-reset>Reset Advancement</button>' : '') : '<a class="admin-btn admin-btn-primary" href="advancement.html?round=' + round.id + '">Select Advancing Contestants</a>') + '</div></section>';
  }
  function renderRound() {
    var round = DATA.getRoundById(roundId); if (!round) { root.innerHTML = '<section class="admin-panel admin-state"><h2>Round not found</h2><p>Choose a round from Results.</p></section>'; return; }
    var slot = workspace('Official Results', 'Combined contestant scores for eligible Required judges.');
    var result = D.calculateRoundResults(roundId);
    if (!result.available) { slot.innerHTML = '<section class="admin-panel admin-state"><span class="admin-state-icon">○</span><h3>Results unavailable</h3><p>' + esc(result.reason) + '</p><a class="admin-btn" href="round.html?id=' + roundId + '">View Round Overview</a></section>' + advancementPanel(round, false) + visibilityControl(roundId, false); return; }
    if (!result.finalized) D.noteResultsCalculated(roundId);
    var finalized = !!result.finalized;
    slot.innerHTML = '<section class="admin-panel admin-result-state"><div><p class="admin-eyebrow">' + (finalized ? 'Finalized Official Result' : 'Provisional Admin Result') + '</p><h3>' + (finalized ? 'Official results locked' : 'Results calculated') + '</h3><p>' + result.eligibleJudgeCount + ' eligible judges · ' + result.contestantCount + ' contestants · ' + (finalized ? 'Finalized by ' + esc(result.finalizedBy) : 'Not finalized yet') + '</p></div>' + (finalized ? badge('finalized') : '<button class="admin-btn admin-btn-primary" data-finalize-open ' + (result.hasTie && !D.isTieAcknowledged(roundId) ? 'disabled title="Acknowledge the tie before finalizing"' : '') + '>Finalize Results</button>') + '</section>' + summary(result, round) +
      (result.hasTie ? '<div class="admin-warning admin-result-tie"><strong>Tie detected.</strong> A final tie-break rule has not yet been configured. Equal scores share a rank; no winner is invented. ' + (finalized ? 'Acknowledged before finalization.' : D.isTieAcknowledged(roundId) ? '<strong>Tie acknowledged.</strong>' : '<button class="admin-btn admin-btn-small" data-tie-acknowledge>Acknowledge Tie</button>') + '</div>' : '') +
      '<section class="admin-panel admin-result-list"><div class="admin-result-head"><span>Rank</span><span>Contestant</span><span>Combined score</span><span>Judges</span><span></span></div>' + result.items.map(function (item) { return '<article class="admin-result-row"><strong class="admin-result-rank">' + item.rank + (item.tied ? '<small>TIED</small>' : '') + '</strong><div class="admin-result-person">' + avatar(item) + '<div><strong>#' + String(item.number).padStart(2, '0') + ' · ' + esc(item.name) + '</strong><small>' + esc(item.country) + '</small></div></div><strong class="admin-result-score">' + Number(item.combinedScore).toFixed(2) + '<small>/ 100</small></strong><span class="admin-result-judge-count">' + item.eligibleJudgeCount + ' Judges</span><a class="admin-btn admin-btn-small" href="' + detailUrl(item.contestantId) + '">View Detail</a></article>'; }).join('') + '</section>' + advancementPanel(round, finalized) + visibilityControl(roundId, finalized);
  }
  function renderDetail() {
    var round = DATA.getRoundById(roundId); if (!round) return;
    var slot = workspace('Result Detail', 'Contestant score and inclusion breakdown.');
    var result = D.calculateRoundResults(roundId);
    if (!result.available) { slot.innerHTML = '<section class="admin-panel admin-state"><h3>Results unavailable</h3><p>' + esc(result.reason) + '</p></section>'; return; }
    var item = result.items.find(function (row) { return row.contestantId === Number(params.get('contestant')); });
    if (!item) { slot.innerHTML = '<section class="admin-panel admin-state"><h3>Contestant not found</h3></section>'; return; }
    var criteria = D.getCriteria(roundId).filter(function (criterion) { return criterion.isScored && !criterion.isParent; });
    var keyMap = { 'evening-gown': 'eveningGown', 'stage-presence': 'stagePresence', 'final-question': 'finalQuestion', 'overall-impression': 'overallImpression' };
    slot.innerHTML = '<a class="admin-round-back" href="' + resultUrl(roundId) + '">← Results</a><section class="admin-panel admin-governance-panel"><div class="admin-result-detail-identity">' + avatar(item) + '<div><p class="admin-eyebrow">#' + String(item.number).padStart(2, '0') + ' · ' + esc(item.country) + '</p><h3>' + esc(item.name) + (item.tied ? ' <span class="admin-result-tied">TIED</span>' : '') + '</h3></div></div><div class="admin-submission-facts"><div><span>Rank</span><strong>' + item.rank + '</strong></div><div><span>Combined Score</span><strong>' + Number(item.combinedScore).toFixed(2) + ' / 100</strong></div><div><span>Eligible Judges</span><strong>' + item.eligibleJudgeCount + '</strong></div><div><span>Result status</span><strong>' + (result.finalized ? 'Finalized' : 'Provisional') + '</strong></div></div></section><div class="admin-section-heading"><div><h2>Judge Breakdown</h2><p>Only Included scores contribute to the official combined score.</p></div></div><section class="admin-panel admin-result-breakdown">' + item.judgeScores.map(function (judge) {
      return '<details class="admin-result-judge-row"><summary><strong>' + esc(judge.judgeNumber) + '</strong><span class="' + (judge.included ? 'is-included' : 'is-excluded') + '">' + (judge.included ? 'Included' : esc(judge.exclusion)) + '</span><strong>' + (judge.total == null ? '—' : Number(judge.total).toFixed(2)) + '</strong></summary><div class="admin-score-detail">' + criteria.map(function (criterion) { var key = keyMap[criterion.id] || criterion.id; var value = judge.criteriaScores && judge.criteriaScores[key]; return '<div><span>' + esc(criterion.name) + '</span><strong>' + (value == null ? '—' : Number(value).toFixed(2)) + '</strong></div>'; }).join('') + '</div></details>';
    }).join('') + '</section>';
  }
  function confirmation() {
    var result = D.calculateRoundResults(roundId);
    if (!result.available || result.finalized || result.hasTie && !D.isTieAcknowledged(roundId)) return;
    var round = DATA.getRoundById(roundId);
    var modal = document.createElement('div'); modal.id = 'result-finalize-modal'; modal.className = 'admin-modal-backdrop';
    modal.innerHTML = '<section class="admin-modal" role="dialog" aria-modal="true" aria-labelledby="finalize-title"><h2 id="finalize-title">Finalize ' + esc(round.name) + ' Results?</h2><p>This will lock the official result snapshot. Normal score and submission editing will remain unavailable.</p><div class="admin-modal-actions"><button class="admin-btn" data-finalize-cancel>Cancel</button><button class="admin-btn admin-btn-primary" data-finalize-confirm>Finalize Results</button></div></section>';
    document.body.appendChild(modal); modal.querySelector('[data-finalize-cancel]').focus();
  }
  document.addEventListener('click', function (event) {
    var target = event.target.closest('[data-tie-acknowledge], [data-finalize-open], [data-finalize-cancel], [data-finalize-confirm], [data-result-visibility], [data-advancement-reset], [data-advancement-reset-confirm]'); if (!target) return;
    if (target.hasAttribute('data-tie-acknowledge')) { if (D.acknowledgeTie(roundId)) renderRound(); }
    else if (target.hasAttribute('data-finalize-open')) confirmation();
    else if (target.hasAttribute('data-finalize-cancel')) document.getElementById('result-finalize-modal').remove();
    else if (target.hasAttribute('data-finalize-confirm')) { if (D.finalizeResults(roundId)) location.reload(); }
    else if (target.hasAttribute('data-result-visibility') && !target.disabled) { if (D.setResultVisibility(roundId, !D.isResultVisible(roundId))) renderRound(); }
    else if (target.hasAttribute('data-advancement-reset')) { var modal = document.createElement('div'); modal.id = 'advancement-reset-modal'; modal.className = 'admin-modal-backdrop'; modal.innerHTML = '<section class="admin-modal" role="dialog" aria-modal="true"><h2>Reset advancement?</h2><p>This clears the target-round contestant assignment, preserves history, and does not change official results.</p><label class="admin-field-label" for="advancement-reset-reason">Reason *</label><textarea class="admin-field admin-textarea" id="advancement-reset-reason" required></textarea><div class="admin-modal-actions"><button class="admin-btn" data-advancement-reset-cancel>Cancel</button><button class="admin-btn admin-btn-danger" data-advancement-reset-confirm>Reset Advancement</button></div></section>'; document.body.appendChild(modal); modal.querySelector('textarea').focus(); }
    else if (target.hasAttribute('data-advancement-reset-confirm')) { var reason = document.getElementById('advancement-reset-reason').value.trim(); if (!reason) { document.getElementById('advancement-reset-reason').focus(); return; } if (D.resetAdvancement(roundId, reason)) location.reload(); }
  });
  document.addEventListener('click', function (event) { if (event.target.closest('[data-advancement-reset-cancel]')) document.getElementById('advancement-reset-modal').remove(); });
  document.addEventListener('keydown', function (event) { if (event.key === 'Escape') { var modal = document.getElementById('result-finalize-modal'); if (modal) modal.remove(); } });
  if (page === 'results') renderGlobal();
  if (page === 'round-results') renderRound();
  if (page === 'result-detail') renderDetail();
})();
