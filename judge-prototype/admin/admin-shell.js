// Shared Admin shell, desktop sidebar, bottom navigation, and More sheet.
(function () {
  function esc(value) { return String(value).replace(/[&<>'"]/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[c]; }); }
  function session() { return window.KreenSession && window.KreenSession.getSession(); }
  function canSwitchToJudge() { var current = session(); return !!(current && current.availableModes.indexOf('judge') !== -1); }
  function itemFor(key) { for (var i = 0; i < adminNavigation.length; i += 1) { var found = adminNavigation[i].items.find(function (item) { return item.key === key; }); if (found) return found; } return null; }
  function renderAdminSidebar(activeNav) {
    var sections = adminNavigation.map(function (group) {
      var label = group.section ? '<span class="admin-nav-label">' + esc(group.section) + '</span>' : '';
      var items = group.items.map(function (item) {
        var className = 'admin-nav-item' + (item.key === activeNav ? ' is-active' : '') + (item.disabled ? ' is-disabled' : '');
        var content = '<span class="admin-nav-icon" aria-hidden="true">' + renderAdminIcon(item.icon) + '</span><span>' + esc(item.label) + '</span>';
        var control = item.disabled ? '<span class="' + className + '" aria-disabled="true">' + content + '</span>' : '<a class="' + className + '" href="' + item.href + '"' + (item.key === activeNav ? ' aria-current="page"' : '') + '>' + content + '</a>';
        return '<li>' + control + '</li>';
      }).join('');
      return '<section class="admin-nav-section">' + label + '<ul class="admin-nav-list">' + items + '</ul></section>';
    }).join('');
    return '<aside class="admin-sidebar" id="admin-sidebar" aria-label="Admin navigation"><a class="admin-brand" href="index.html"><span class="admin-brand-mark">K</span><span class="admin-brand-name">KREEN JUDGING</span></a><nav class="admin-nav">' + sections + '</nav>' + renderAdminFooter() + '</aside>';
  }
  function renderAdminEventContext() {
    var event = { eventName: 'King & Queen of the Pacific', eventYear: '2026' };
    try {
      var stored = JSON.parse(localStorage.getItem('kreenAdminConfiguration') || '{}').eventSettings || {};
      event.eventName = stored.eventName || event.eventName;
      event.eventYear = stored.eventYear || event.eventYear;
    } catch (e) {}
    var current = session();
    return '<header class="admin-context-bar"><div class="admin-context-inner"><div class="admin-context-event"><span class="admin-context-name">' + esc(event.eventName) + '</span><span class="admin-context-meta">' + esc(event.eventYear) + '</span></div><div class="admin-context-user"><span class="admin-user-dot"></span>' + esc(current ? current.currentUser.label : 'Admin') + '</div></div></header>';
  }
  function renderAdminFooter() { var current = session(); return '<div class="admin-sidebar-footer"><p class="admin-user-role">' + esc(current ? current.currentUser.label : 'Admin') + '</p><p class="admin-user-name">' + esc(current ? current.currentUser.name : '') + '</p>' + (canSwitchToJudge() ? '<a class="admin-mode-switch" href="../mode.html" data-switch-mode="judge">← Switch to Judge Mode</a>' : '') + '<button class="admin-mode-switch admin-logout" type="button" data-log-out>Log Out</button></div>'; }
  function renderBottomNavigation(activeNav) {
    var activeMobileKey = ['contestants', 'judges', 'settings', 'audit'].indexOf(activeNav) !== -1 ? 'more' : activeNav;
    var links = adminBottomNavigation.map(function (key) {
      var item = key === 'more' ? { label: 'More', mobileLabel: 'More', icon: 'more', href: null } : itemFor(key);
      var active = key === activeMobileKey;
      var cls = 'admin-bottom-item' + (active ? ' is-active' : '');
      var content = '<span class="admin-bottom-icon" aria-hidden="true">' + renderAdminIcon(item.icon) + '</span><span class="admin-bottom-label">' + esc(item.mobileLabel) + '</span>';
      return key === 'more'
        ? '<button class="' + cls + '" type="button" data-more-open aria-expanded="false">' + content + '</button>'
        : '<a class="' + cls + '" href="' + item.href + '"' + (active ? ' aria-current="page"' : '') + '>' + content + '</a>';
    }).join('');
    return '<nav class="admin-bottom-nav" aria-label="Primary navigation">' + links + '</nav>';
  }
  function renderMoreSheet() {
    var current = session();
    function moreIcon(name) { return '<span class="admin-more-icon" aria-hidden="true">' + renderAdminIcon(name) + '</span>'; }
    return '<div class="admin-more-backdrop" hidden><section class="admin-more-sheet" role="dialog" aria-modal="true" aria-labelledby="admin-more-title"><div class="admin-sheet-handle"></div><header class="admin-more-header"><div><p class="admin-user-role">' + esc(current ? current.currentUser.label : 'Admin') + '</p><h2 id="admin-more-title">' + esc(current ? current.currentUser.name : '') + '</h2></div><button class="admin-icon-btn" type="button" data-more-close aria-label="Close menu">×</button></header><nav class="admin-more-links" aria-label="More destinations"><a href="contestants.html">' + moreIcon('person') + 'Contestants</a><a href="judges.html">' + moreIcon('judges') + 'Judges</a><a href="settings.html">' + moreIcon('settings') + 'Settings</a><a href="audit.html">' + moreIcon('history') + 'Audit Log</a>' + (canSwitchToJudge() ? '<a href="../mode.html" data-switch-mode="judge">' + moreIcon('switch') + 'Switch to Judge Mode</a>' : '') + '<button type="button" data-log-out>' + moreIcon('logout') + 'Log Out</button></nav></section></div>';
  }
  function renderAdminShell() {
    var app = document.querySelector('.admin-app'); var root = document.getElementById('admin-root'); if (!app || !root) return;
    if (window.KreenSession && !window.KreenSession.requireMode('admin')) return;
    var globalActiveNav = app.dataset.roundTab ? 'rounds' : (app.dataset.activeNav || (app.dataset.adminPage === 'round' ? 'rounds' : app.dataset.adminPage) || 'overview');
    var roundActiveTab = app.dataset.roundTab || null;
    window.adminNavigationState = { globalActiveNav: globalActiveNav, roundActiveTab: roundActiveTab };
    var template = document.getElementById('admin-page-template'); var content = template ? template.content.cloneNode(true) : document.createDocumentFragment();
    root.innerHTML = '<div class="admin-shell">' + renderAdminSidebar(globalActiveNav) + '<main class="admin-main">' + renderAdminEventContext() + '<div class="admin-content" id="admin-page-content"></div></main></div>' + renderBottomNavigation(globalActiveNav) + renderMoreSheet();
    root.dataset.globalActiveNav = globalActiveNav;
    if (roundActiveTab) root.dataset.roundActiveTab = roundActiveTab;
    document.getElementById('admin-page-content').appendChild(content);
  }
  function setMoreOpen(isOpen) {
    var sheet = document.querySelector('.admin-more-backdrop');
    var trigger = document.querySelector('[data-more-open]');
    if (!sheet || !trigger) return;
    sheet.hidden = !isOpen;
    trigger.setAttribute('aria-expanded', String(isOpen));
    if (isOpen) { var closeButton = sheet.querySelector('[data-more-close]'); if (closeButton) closeButton.focus(); }
    else trigger.focus();
  }
  document.addEventListener('click', function (event) {
    var switchLink = event.target.closest('[data-switch-mode]');
    if (switchLink) { event.preventDefault(); window.KreenSession.switchMode('judge', '../pages/my-rounds.html'); return; }
    if (event.target.closest('[data-log-out]')) { window.KreenSession.logout(); location.href = '../index.html'; return; }
    var trigger = event.target.closest('[data-more-open]');
    var backdrop = document.querySelector('.admin-more-backdrop');
    if (trigger) { setMoreOpen(true); return; }
    if (backdrop && (event.target === backdrop || event.target.closest('.admin-more-sheet [data-more-close]'))) setMoreOpen(false);
  });
  document.addEventListener('keydown', function (event) {
    var sheet = document.querySelector('.admin-more-backdrop');
    if (event.key === 'Escape' && sheet && !sheet.hidden) setMoreOpen(false);
  });
  window.renderAdminShell = renderAdminShell; window.renderAdminSidebar = renderAdminSidebar; window.renderAdminEventContext = renderAdminEventContext; window.renderAdminFooter = renderAdminFooter; window.renderAdminBottomNavigation = renderBottomNavigation;
  renderAdminShell();
})();
