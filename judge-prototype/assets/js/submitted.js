// submitted.html — post-submit confirmation. Guarded: only reachable
// normally once isSubmitted() is true; otherwise redirected to review.html
// (see navigation.js guardSubmitted()). ?preview=1 bypasses the guard and
// renders a mocked "as if submitted" view (15 scored, dummy 21:42 time)
// WITHOUT reading or writing real stored state, exactly per the refactor
// brief — this is display-only, never a way to fake a real submission.

(function () {
  const DATA = window.JudgePrototypeData;
  const S = window.JudgeState;
  const Nav = window.JudgeNav;

  window.JudgeChrome.init({ standbyTimeout: false });

  const round = Nav.guardAssignedRound();
  if (!round) return;
  if (!Nav.guardSubmitted()) return; // already redirected

  document.getElementById('submitted-round').textContent = round.name;

  const statEl = document.getElementById('submitted-stat');
  const timeEl = document.getElementById('submitted-time');

  if (Nav.isPreviewMode() && !S.isSubmitted()) {
    // Mocked numbers only — never derived from or written to real state.
    statEl.textContent = DATA.getRoundContestants(round.id).length + ' contestants scored';
    timeEl.textContent = 'Submitted at 21:42';
  } else {
    const counts = S.countByStatus();
    statEl.textContent = counts.total + ' contestants scored';
    const submittedAt = S.getSubmission(round.id).submittedAt;
    if (submittedAt) {
      const d = new Date(submittedAt);
      timeEl.textContent = 'Submitted at ' + String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
    }
  }

  document.getElementById('submitted-return-standby').addEventListener('click', function () { Nav.goToMyRounds(); });
  document.getElementById('submitted-view-scores').addEventListener('click', function () { Nav.goToReview(round.id); });
})();
