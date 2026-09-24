// One navigation model feeds desktop sidebar and small-screen navigation.
var adminNavigation = [
  { section: null, items: [{ key: 'overview', label: 'Overview', mobileLabel: 'Home', icon: 'home', href: 'index.html' }] },
  { section: 'Event', items: [
    { key: 'rounds', label: 'Rounds', mobileLabel: 'Rounds', icon: 'rounds', href: 'rounds.html' },
    { key: 'contestants', label: 'Contestants', icon: 'person', href: 'contestants.html' },
    { key: 'judges', label: 'Judges', icon: 'judges', href: 'judges.html' }
  ] },
  { section: 'Operations', items: [
    { key: 'live', label: 'Live', mobileLabel: 'Live', icon: 'live', href: 'live.html' },
    { key: 'results', label: 'Results', mobileLabel: 'Results', icon: 'results', href: 'results.html' }
  ] },
  { section: 'System', items: [
    { key: 'settings', label: 'Settings', icon: 'settings', href: 'settings.html' },
    { key: 'audit', label: 'Audit Log', icon: 'history', href: 'audit.html' }
  ] }
];
var adminBottomNavigation = ['overview', 'rounds', 'live', 'results', 'more'];

// One softened-outline SVG family for all shared Admin navigation surfaces.
var adminIconPaths = {
  home: '<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z"/>',
  rounds: '<rect x="5" y="4" width="14" height="5" rx="1.5"/><rect x="3" y="10" width="18" height="5" rx="1.5"/><rect x="5" y="16" width="14" height="5" rx="1.5"/>',
  person: '<circle cx="12" cy="7.5" r="3.5"/><path d="M5 21v-2a7 7 0 0 1 14 0v2z"/>',
  judges: '<rect x="3" y="4" width="18" height="16" rx="2.5"/><circle cx="9" cy="10" r="2.5"/><path d="M5.5 16a3.5 3.5 0 0 1 7 0M15 9h3M15 13h3M15 17h2"/>',
  live: '<circle cx="12" cy="12" r="2.5"/><path d="M7.5 7.5a6.4 6.4 0 0 0 0 9M16.5 7.5a6.4 6.4 0 0 1 0 9M4.5 4.5a10.6 10.6 0 0 0 0 15M19.5 4.5a10.6 10.6 0 0 1 0 15"/>',
  results: '<path d="M4 20h16M5 20v-7h4v7M10 20V5h4v15M15 20v-10h4v10"/>',
  settings: '<circle cx="12" cy="12" r="3"/><path d="M10 2.5h4l.5 2.1 1.5.7 1.9-1.2 2.8 2.8-1.2 1.9.7 1.5 2.1.5v4l-2.1.5-.7 1.5 1.2 1.9-2.8 2.8-1.9-1.2-1.5.7-.5 2.1h-4l-.5-2.1-1.5-.7-1.9 1.2-2.8-2.8 1.2-1.9-.7-1.5-2.1-.5v-4l2.1-.5.7-1.5-1.2-1.9 2.8-2.8 1.9 1.2 1.5-.7z"/>',
  history: '<path d="M3.5 8A9 9 0 1 1 3 13M3.5 3.5V8H8"/><path d="M12 7v5l3.5 2"/>',
  more: '<circle cx="4" cy="12" r="1.65" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.65" fill="currentColor" stroke="none"/><circle cx="20" cy="12" r="1.65" fill="currentColor" stroke="none"/>',
  switch: '<path d="M4 7h15m-4-4 4 4-4 4M20 17H5m4-4-4 4 4 4"/>',
  logout: '<path d="M10 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h5M14 7l5 5-5 5M19 12H9"/>'
};
function renderAdminIcon(name) {
  return '<svg class="admin-icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">' + (adminIconPaths[name] || adminIconPaths.more) + '</svg>';
}
