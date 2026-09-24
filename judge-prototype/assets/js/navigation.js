// Judge Mode navigation and round guards. Every judge page carries ?round=N.
(function () {
  const S = window.JudgeState;
  function qs(name) { return new URLSearchParams(window.location.search).get(name); }
  function isPreviewMode() { return qs('preview') === '1'; }
  function withPreview(url) { return url + (isPreviewMode() ? (url.indexOf('?') === -1 ? '?' : '&') + 'preview=1' : ''); }
  function goToMyRounds() { window.location.href = withPreview('my-rounds.html'); }
  function goToStandby(id) { window.location.href = withPreview('standby.html?round=' + encodeURIComponent(id || S.getActiveRoundId())); }
  function goToContestants(id) { window.location.href = withPreview('contestants.html?round=' + encodeURIComponent(id || S.getActiveRoundId())); }
  function goToScoring(id, from, roundId) { window.location.href = withPreview('scoring.html?round=' + encodeURIComponent(roundId || S.getActiveRoundId()) + '&id=' + encodeURIComponent(id) + (from ? '&from=' + encodeURIComponent(from) : '')); }
  function goToReview(id) { window.location.href = withPreview('review.html?round=' + encodeURIComponent(id || S.getActiveRoundId())); }
  function goToSubmitted(id) { window.location.href = withPreview('submitted.html?round=' + encodeURIComponent(id || S.getActiveRoundId())); }
  function goToResults(id) { window.location.href = 'results.html?round=' + encodeURIComponent(id || S.getActiveRoundId()); }
  function showUnavailable() { const shell = document.querySelector('.app-shell'); if (shell) shell.innerHTML = '<main class="round-unavailable" role="alert"><p class="event-eyebrow">Judge Mode</p><h1>Round unavailable</h1><p>This round is not assigned to you.</p><a class="primary-action" href="my-rounds.html">Back to My Rounds</a></main>'; }
  function resolveRound() { const raw = qs('round'); const id = Number(raw); if (!raw || Number.isNaN(id) || !window.JudgePrototypeData.getRound(id)) { if (isPreviewMode()) { S.setActiveRound(1, false); return 1; } showUnavailable(); return null; } S.setActiveRound(id, !isPreviewMode()); return id; }
  function guardAssignedRound() { const id = resolveRound(); if (!id) return null; if (!isPreviewMode() && !S.canJudgeRound(id) && !S.getSubmission(id).isSubmitted) { showUnavailable(); return null; } return window.JudgePrototypeData.getRound(id); }
  function guardScoringId(rawId) { if (!guardAssignedRound()) return null; if (!isPreviewMode() && !S.canJudgeRound(S.getActiveRoundId()) && !S.isSubmitted()) { showUnavailable(); return null; } const id = Number(rawId); const contestant = S.getContestant(id); if (isPreviewMode()) return contestant ? id : window.JudgePrototypeData.getRoundContestants(S.getActiveRoundId())[0].id; if (!rawId || Number.isNaN(id) || !contestant) { goToContestants(); return null; } return id; }
  function guardSubmitted() { if (isPreviewMode()) return true; if (!S.isSubmitted()) { goToReview(); return false; } return true; }
  window.JudgeNav = { isPreviewMode, goToMyRounds, goToStandby, goToContestants, goToScoring, goToReview, goToSubmitted, goToResults, getScoringOrigin: function () { return qs('from') === 'review' ? 'review' : 'gallery'; }, resolveRound, guardAssignedRound, guardScoringId, guardSubmitted };
})();
