(function () {
  const DATA = window.JudgePrototypeData;
  const S = window.JudgeState;
  const Nav = window.JudgeNav;
  const preview = Nav.isPreviewMode();
  const grid = document.getElementById('my-rounds-grid');
  const name = document.getElementById('my-rounds-judge');
  const session = window.KreenSession && window.KreenSession.getSession();
  const profile = session && session.currentUser.judgeProfile;
  const judgeId = profile ? Number(profile.id) : DATA.judge.number;
  name.textContent = session ? session.currentUser.name : DATA.judge.name;
  document.getElementById('my-rounds-account').textContent = session ? session.currentUser.label : 'Judge';
  if (profile && session.currentUser.name !== profile.name) {
    const note = document.getElementById('my-rounds-profile-note'); note.textContent = 'Judging as ' + profile.name + ' · Judge ' + String(profile.id).padStart(2, '0'); note.hidden = false;
  }
  const switchButton = document.getElementById('judge-switch-admin');
  switchButton.hidden = !session || session.availableModes.indexOf('admin') === -1;
  switchButton.addEventListener('click', function () { window.KreenSession.switchMode('admin', '../admin/index.html'); });
  document.getElementById('judge-log-out').addEventListener('click', function () { window.KreenSession.logout(); location.href = '../index.html'; });
  function card(round) {
    let assigned = round.id === 1;
    let assignmentStatus = 'assigned';
    try { const config = JSON.parse(localStorage.getItem('kreenAdminConfiguration') || '{}'); const configured = config.judgeAssignments && config.judgeAssignments[round.id]; const own = (configured || []).find(function (item) { return Number(item.judgeId) === judgeId; }); if (configured && !own) assigned = false; if (own) { assignmentStatus = own.assignmentStatus; if (own.assignmentStatus === 'unassigned') assigned = false; else if (round.status !== 'draft') assigned = true; } } catch (e) {}
    const submission = assigned ? S.getSubmission(round.id) : { isSubmitted: false };
    const counts = assigned ? S.countByStatus(round.id) : { scored: 0, total: DATA.getRoundContestants(round.id).length };
    let label = 'Not Available'; let detail = 'Round not open yet'; let action = '<span class="round-card-disabled">Unavailable</span>';
    if (assigned && (assignmentStatus === 'excused' || assignmentStatus === 'removed')) { label = assignmentStatus === 'excused' ? 'Excused' : 'Removed'; detail = assignmentStatus === 'excused' ? 'This round is paused for you by Admin' : 'Your round assignment is inactive'; }
    else if (assigned && round.status === 'finalized') { label = '✓ Completed'; detail = round.resultsVisibleToJudges ? 'Results Available' : 'Results hidden'; action = '<div class="my-round-actions">' + (round.resultsVisibleToJudges ? '<button class="round-card-action" data-results="1" data-round="' + round.id + '">View Results</button>' : '') + (submission.isSubmitted ? '<button class="round-card-action is-secondary" data-submitted="1" data-round="' + round.id + '">View Submission</button>' : '') + '</div>'; }
    else if (assigned && round.status === 'closed') { label = submission.isSubmitted ? 'Closed · Submitted' : 'Closed'; detail = 'Scoring is read-only'; if (submission.isSubmitted) action = '<button class="round-card-action" data-submitted="1" data-round="' + round.id + '">View Submission</button>'; }
    else if (assigned && submission.isSubmitted) { label = '✓ Submitted'; detail = counts.scored + ' / ' + counts.total + ' scored' + (submission.submittedAt ? ' · Submitted at ' + new Date(submission.submittedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''); action = '<button class="round-card-action" data-submitted="1" data-round="' + round.id + '">View Submission</button>'; }
    else if (assigned && submission.status === 'reopened') { label = 'Submission Reopened'; detail = submission.reason || 'Correction requested by Head Judge'; action = '<button class="round-card-action" data-round="' + round.id + '">Continue Judging</button>'; }
    else if (assigned && counts.scored > 0) { label = 'In Progress'; detail = counts.scored + ' / ' + counts.total + ' scored'; action = '<button class="round-card-action" data-round="' + round.id + '">Continue Judging</button>'; }
    else if (assigned && round.status === 'open') { label = 'Open'; detail = 'Ready to judge · ' + counts.total + ' contestants'; action = '<button class="round-card-action" data-round="' + round.id + '">Enter Round</button>'; }
    return '<article class="my-round-card"><div class="my-round-card-top"><p class="my-round-sequence">' + String(round.id).padStart(2, '0') + ' · ROUND</p><span class="my-round-status ' + (label.indexOf('Submitted') !== -1 ? 'is-submitted' : label === 'Not Available' ? 'is-muted' : '') + '">' + label + '</span></div><h2>' + round.name + '</h2><p class="my-round-contestants">' + DATA.getRoundContestants(round.id).length + ' Contestants</p><p class="my-round-detail">' + detail + '</p>' + action + '</article>';
  }
  grid.innerHTML = DATA.rounds.map(card).join('');
  grid.addEventListener('click', function (event) { const button = event.target.closest('[data-round]'); if (!button) return; const id = Number(button.dataset.round); if (button.dataset.results) Nav.goToResults(id); else if (button.dataset.submitted) Nav.goToSubmitted(id); else Nav.goToStandby(id); });
})();
