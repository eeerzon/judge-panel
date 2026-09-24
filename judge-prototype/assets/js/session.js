// Prototype-only identity, capability, and mode routing. Not authentication.
(function () {
  var KEY = 'kreenPrototypeSession';
  var users = [
    { id: 'ersa', name: 'Ersa', email: 'ersa@kreen.test', label: 'Super Admin', capabilities: ['admin:access', 'judge:score'], judgeProfile: { id: 3, name: 'Amanda Wijaya' } },
    { id: 'amanda', name: 'Amanda Wijaya', email: 'amanda@kreen.test', label: 'Judge', capabilities: ['judge:score'], judgeProfile: { id: 3, name: 'Amanda Wijaya' } },
    { id: 'event-admin', name: 'Event Admin', email: 'admin@kreen.test', label: 'Event Admin', capabilities: ['admin:access'], judgeProfile: null }
  ];
  function modesFor(user) {
    return ['admin', 'judge'].filter(function (mode) { return user.capabilities.indexOf(mode === 'admin' ? 'admin:access' : 'judge:score') !== -1; });
  }
  function getSession() {
    try {
      var parsed = JSON.parse(localStorage.getItem(KEY) || 'null');
      var fixture = parsed && users.find(function (user) { return user.id === parsed.currentUser.id; });
      if (!fixture) return null;
      var modes = modesFor(fixture);
      return { currentUser: { id: fixture.id, name: fixture.name, email: fixture.email, label: fixture.label, judgeProfile: fixture.judgeProfile }, availableModes: modes, currentMode: modes.indexOf(parsed.currentMode) !== -1 ? parsed.currentMode : null };
    } catch (e) { return null; }
  }
  function write(session) { try { localStorage.setItem(KEY, JSON.stringify(session)); return true; } catch (e) { return false; } }
  function signIn(identifier) {
    var normalized = String(identifier || '').trim().toLowerCase();
    var user = users.find(function (item) { return item.id === normalized || item.email === normalized || item.name.toLowerCase() === normalized; });
    if (!user) return null;
    var session = { currentUser: { id: user.id, name: user.name, email: user.email, label: user.label, judgeProfile: user.judgeProfile }, availableModes: modesFor(user), currentMode: null };
    return write(session) ? session : null;
  }
  function selectMode(mode) {
    var session = getSession();
    if (!session || session.availableModes.indexOf(mode) === -1) return false;
    session.currentMode = mode;
    return write(session);
  }
  function logout() { try { localStorage.removeItem(KEY); } catch (e) {} }
  function isPreview() { return new URLSearchParams(location.search).get('preview') === '1'; }
  function requireMode(mode, relativeRoot) {
    if (isPreview()) return true; // Deliberate dev.html visual-review escape hatch.
    var session = getSession();
    if (session && session.currentMode === mode && session.availableModes.indexOf(mode) !== -1) return true;
    document.documentElement.style.visibility = 'hidden';
    location.replace((relativeRoot || '../') + (session ? 'mode.html' : 'index.html'));
    return false;
  }
  function switchMode(mode, destination) { if (selectMode(mode)) location.href = destination; }
  window.KreenSession = { getSession: getSession, signIn: signIn, selectMode: selectMode, logout: logout, requireMode: requireMode, switchMode: switchMode, modesFor: modesFor };
  if (isPreview()) document.body.setAttribute('data-dev-preview', 'true');
  var path = location.pathname;
  if (/\/admin\/[^/]+\.html$/.test(path)) requireMode('admin');
  else if (/\/pages\/[^/]+\.html$/.test(path)) requireMode('judge');
})();
