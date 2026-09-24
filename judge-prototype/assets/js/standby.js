// standby.html — idle/lock screen. Tap anywhere (or Enter/Space) goes to
// Contestants. If judging was already submitted, wake still goes to
// Contestants — Gallery renders its own read-only/submitted state there
// (see contestants.js) rather than Standby trying to guess which screen
// "submitted" should mean.

(function () {
  const DATA = window.JudgePrototypeData;
  const S = window.JudgeState;
  const Nav = window.JudgeNav;

  window.JudgeChrome.init();
  const round = Nav.guardAssignedRound();
  if (!round) return;

  const screen = document.getElementById('standby-screen');
  const logoImg = document.getElementById('standby-logo');
  const yearEl = document.getElementById('standby-year');
  const roundEl = document.getElementById('standby-round');
  const judgeEl = document.getElementById('standby-judge-identity');
  const submittedNote = document.getElementById('standby-submitted-note');
  const clockEl = document.getElementById('clock');
  const roundsLink = document.getElementById('standby-my-rounds');

  logoImg.src = DATA.event.logo;
  yearEl.textContent = String(DATA.event.year);
  roundEl.textContent = round.name;
  judgeEl.textContent = 'Judge ' + String(DATA.judge.number).padStart(2, '0') + ' · ' + DATA.judge.name;
  submittedNote.hidden = !S.isSubmitted();
  if (roundsLink) roundsLink.addEventListener('click', function (event) { event.stopPropagation(); });

  function updateClock() {
    const now = new Date();
    clockEl.textContent = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
  }
  updateClock();
  setInterval(updateClock, 15000);

  function wake() {
    Nav.goToContestants(round.id);
  }

  screen.addEventListener('click', wake);
  screen.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      wake();
    }
  });
})();
