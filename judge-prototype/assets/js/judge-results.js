// Read-only Judge Results. Visibility is checked on direct entry as well as in My Rounds.
(function () {
  const DATA = window.JudgePrototypeData;
  const root = document.getElementById('judge-results-content');
  const roundId = Number(new URLSearchParams(location.search).get('round'));
  const round = DATA.getRound(roundId);
  let config = {};
  try { config = JSON.parse(localStorage.getItem('kreenAdminConfiguration') || '{}'); } catch (e) {}
  const assignment = ((config.judgeAssignments || {})[roundId] || []).find(function (item) { return Number(item.judgeId) === DATA.judge.number; });
  const snapshot = (config.resultSnapshotByRound || {})[roundId];
  const allowed = !!(round && round.status === 'finalized' && round.resultsVisibleToJudges && assignment && assignment.assignmentStatus === 'assigned' && snapshot && Array.isArray(snapshot.items));
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>'"]/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[c]; }); }
  if (!allowed) {
    root.innerHTML = '<div class="judge-results-unavailable"><p class="event-eyebrow">King &amp; Queen of the Pacific</p><h1>Results Not Available</h1><p>Official results for this round are not available to you.</p><a class="judge-results-back" href="my-rounds.html">← Back to My Rounds</a></div>';
    return;
  }
  root.innerHTML = '<header class="judge-results-header"><a class="judge-results-back" href="my-rounds.html">← My Rounds</a><p class="event-eyebrow">King &amp; Queen of the Pacific</p><p class="judge-results-round">' + esc(round.name) + '</p><h1>Official Results</h1><p>Finalized ranking and combined scores</p></header><section class="judge-results-list" aria-label="Official ranking">' + snapshot.items.map(function (item) {
    return '<article class="judge-results-row"><strong class="judge-results-rank">' + item.rank + (item.tied ? '<small>TIED</small>' : '') + '</strong><div><span class="judge-results-number">#' + String(item.number).padStart(2, '0') + '</span><h2>' + esc(item.name) + '</h2><p>' + esc(item.country) + '</p></div><strong class="judge-results-score">' + Number(item.combinedScore).toFixed(2) + '<small>/ 100</small></strong></article>';
  }).join('') + '</section><p class="judge-results-note">Official combined score only. Individual judges’ scores remain private.</p>';
})();
