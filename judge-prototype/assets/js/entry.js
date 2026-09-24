// Login and workspace selection share the same local session fixture.
(function () {
  var S = window.KreenSession;
  var login = document.getElementById('entry-login-form');
  if (login) {
    if (S.getSession()) { location.replace('mode.html'); return; }
    var error = document.getElementById('entry-error');
    function enter(identity) {
      if (!S.signIn(identity)) { error.textContent = 'We could not find that account. Try one of the Demo Access options.'; error.hidden = false; return; }
      location.href = 'mode.html';
    }
    login.addEventListener('submit', function (event) { event.preventDefault(); if (!login.reportValidity()) return; enter(login.elements.identity.value); });
    document.querySelectorAll('[data-demo-user]').forEach(function (button) { button.addEventListener('click', function () { enter(button.dataset.demoUser); }); });
    return;
  }
  var selector = document.getElementById('mode-options');
  if (!selector) return;
  var session = S.getSession();
  if (!session) { location.replace('index.html'); return; }
  var name = document.getElementById('mode-user-name');
  name.textContent = session.currentUser.name;
  var choices = {
    admin: { icon: '◫', label: 'Admin Mode', heading: 'Manage judging operations', description: 'Set up rounds, coordinate judges and contestants, monitor progress, and manage results.', action: 'Open Admin', destination: 'admin/index.html' },
    judge: { icon: '✦', label: 'Judge Mode', heading: 'Score assigned rounds', description: 'View your assigned rounds and continue contestant scoring.', action: 'Open Judge Mode', destination: 'pages/my-rounds.html' }
  };
  selector.classList.toggle('is-single', session.availableModes.length === 1);
  selector.innerHTML = session.availableModes.map(function (mode) {
    var item = choices[mode];
    return '<article class="mode-card"><span class="mode-icon" aria-hidden="true">' + item.icon + '</span><p class="mode-label">' + item.label + '</p><h2>' + item.heading + '</h2><p class="mode-description">' + item.description + '</p><button class="entry-btn entry-btn-primary" type="button" data-open-mode="' + mode + '">' + item.action + ' <span aria-hidden="true">→</span></button></article>';
  }).join('');
  selector.addEventListener('click', function (event) {
    var button = event.target.closest('[data-open-mode]'); if (!button) return;
    var mode = button.dataset.openMode;
    if (S.selectMode(mode)) location.href = choices[mode].destination;
  });
  document.getElementById('mode-logout').addEventListener('click', function () { S.logout(); location.href = 'index.html'; });
})();
