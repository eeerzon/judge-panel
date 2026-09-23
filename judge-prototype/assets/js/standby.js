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

  const screen = document.getElementById('standby-screen');
  const logoImg = document.getElementById('standby-logo');
  const yearEl = document.getElementById('standby-year');
  const roundEl = document.getElementById('standby-round');
  const judgeEl = document.getElementById('standby-judge-identity');
  const submittedNote = document.getElementById('standby-submitted-note');
  const clockEl = document.getElementById('clock');

  logoImg.src = DATA.event.logo;
  yearEl.textContent = String(DATA.event.year);
  roundEl.textContent = DATA.round.name;
  judgeEl.textContent = 'Judge ' + String(DATA.judge.number).padStart(2, '0') + ' · ' + DATA.judge.name;
  submittedNote.hidden = !S.isSubmitted();

  function updateClock() {
    const now = new Date();
    clockEl.textContent = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
  }
  updateClock();
  setInterval(updateClock, 15000);

  function wake() {
    Nav.goToContestants();
  }

  screen.addEventListener('click', wake);
  screen.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      wake();
    }
  });
})();
