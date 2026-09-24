// The only renderer for round context and its secondary navigation.
(function () {
  var tabs = [
    { key: 'overview', label: 'Overview', href: function (id) { return 'round.html?id=' + id; } },
    { key: 'monitoring', label: 'Monitoring', href: function (id) { return 'monitoring.html?round=' + id; } },
    { key: 'contestants', label: 'Contestants', href: function (id) { return 'round-contestants.html?round=' + id; } },
    { key: 'judges', label: 'Judges', href: function (id) { return 'round-judges.html?round=' + id; } },
    { key: 'criteria', label: 'Criteria', href: function (id) { return 'criteria.html?round=' + id; } },
    { key: 'results', label: 'Results', href: function (id) { return 'round-results.html?round=' + id; } },
    { key: 'settings', label: 'Settings · Soon', disabled: true }
  ];
  var previousResizeHandler = null;
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>\'"]/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[c]; }); }
  function renderRoundWorkspace(options) {
    options = options || {};
    var DATA = window.KreenAdminData;
    var DOMAIN = window.KreenAdminDomain;
    var round = DATA && DATA.getRoundById(options.roundId);
    var target = typeof options.contentTarget === 'string' && options.contentTarget.charAt(0) === '#'
      ? document.querySelector(options.contentTarget)
      : document.getElementById(options.contentTarget || 'admin-page-content');
    if (!round || !target) return null;
    var activeTab = options.activeTab || 'overview';
    var readiness = DOMAIN && DOMAIN.getRoundReadiness(round.id);
    var contestantCount = readiness ? readiness.contestantsAssigned : round.contestants;
    var judgeCount = readiness ? readiness.judgesAssigned : round.judges;
    var tabsMarkup = tabs.map(function (tab) {
      var active = tab.key === activeTab;
      var cls = 'admin-tab' + (active ? ' is-active' : '');
      if (tab.disabled) return '<span class="' + cls + ' is-disabled" aria-disabled="true">' + tab.label + '</span>';
      if (active) return '<span class="' + cls + '" aria-current="page">' + tab.label + '</span>';
      return '<a class="' + cls + '" href="' + tab.href(round.id) + '">' + tab.label + '</a>';
    }).join('');
    target.innerHTML = '<section class="admin-panel admin-round-context"><div class="admin-round-context-top"><div class="admin-round-heading"><a class="admin-round-back" href="rounds.html">← Rounds</a><p class="admin-eyebrow">Round workspace</p><div class="admin-round-title-row"><h1 class="admin-round-name">' + esc(round.name) + '</h1><span class="admin-status admin-status-' + esc(round.status) + '"><span class="admin-status-dot"></span>' + esc(round.status.charAt(0).toUpperCase() + round.status.slice(1)) + '</span></div></div><div class="admin-round-facts"><span><strong>' + contestantCount + '</strong> contestants</span><span class="admin-round-fact-separator" aria-hidden="true">·</span><span><strong>' + judgeCount + '</strong> judges</span></div></div><div class="admin-tab-wrap"><div class="admin-tab-scroll"><nav class="admin-tabs" aria-label="Round sections">' + tabsMarkup + '</nav></div></div></section><div class="admin-round-page-slot"><header class="admin-page-header"><div><h2 class="admin-page-title">' + esc(options.pageTitle || 'Round overview') + '</h2><p class="admin-page-description">' + esc(options.pageDescription || '') + '</p></div></header><div class="admin-round-content" id="round-page-content"></div></div>';
    var tabScroll = target.querySelector('.admin-tab-scroll');
    var tabWrap = target.querySelector('.admin-tab-wrap');
    var active = tabScroll.querySelector('[aria-current="page"]');
    function updateTabAffordance() {
      var maxScroll = tabScroll.scrollWidth - tabScroll.clientWidth;
      tabWrap.classList.toggle('can-scroll-right', maxScroll > 2 && tabScroll.scrollLeft < maxScroll - 2);
      tabWrap.classList.toggle('can-scroll-left', maxScroll > 2 && tabScroll.scrollLeft > 2);
    }
    function revealActiveTab() {
      if (active) {
        var viewport = tabScroll.getBoundingClientRect();
        var tab = active.getBoundingClientRect();
        if (tab.left < viewport.left + 12) tabScroll.scrollLeft += tab.left - viewport.left - 12;
        else if (tab.right > viewport.right - 12) tabScroll.scrollLeft += tab.right - viewport.right + 12;
      }
      updateTabAffordance();
    }
    tabScroll.addEventListener('scroll', updateTabAffordance, { passive: true });
    if (previousResizeHandler) window.removeEventListener('resize', previousResizeHandler);
    previousResizeHandler = revealActiveTab;
    window.addEventListener('resize', previousResizeHandler);
    window.requestAnimationFrame(revealActiveTab);
    return target.querySelector('#round-page-content');
  }
  window.adminRoundTabs = tabs;
  window.renderRoundWorkspace = renderRoundWorkspace;
})();
