// Phase 4A — Event master data. Local-only CRUD presentation for contestants and judges.
(function () {
  var app = document.querySelector('.admin-app');
  if (!app || (app.dataset.configPage !== 'contestants' && app.dataset.configPage !== 'judges')) return;
  var kind = app.dataset.configPage;
  var D = window.KreenAdminDomain; var DATA = window.KreenAdminData;
  var state = { contestants: D.getContestants(), judges: D.getJudges() };
  var esc = function (value) { return String(value == null ? '' : value).replace(/[&<>'"]/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[c]; }); };
  var root = document.getElementById('config-content'); var drawer = document.getElementById('admin-drawer');
  var pendingFilePhoto = ''; var currentDrawerPhoto = ''; var photoSession = 0; var photoReading = false;
  function saveState(item) { D.saveMasterRecord(kind, item); }
  function roundsFor(item) { return DATA.rounds.filter(function (round) { return kind === 'contestants' ? D.getRoundContestants(round.id).some(function (x) { return Number(x.id) === Number(item.id); }) : D.getRoundJudges(round.id).some(function (x) { return Number(x.judgeId) === Number(item.id) && x.assignmentStatus === 'assigned'; }); }).map(function (round) { return round.name; }); }
  function initials(item) { return (item.name || '?').split(/\s+/).slice(0, 2).map(function (word) { return word.charAt(0); }).join('').toUpperCase(); }
  function avatar(item) { return '<span class="admin-master-avatar admin-master-avatar-fallback">' + esc(initials(item)) + '</span>'; }
  function photo(item) {
    var fallback = '<span class="admin-contestant-photo-fallback">' + esc(initials(item)) + '</span>';
    var seedPhoto = D.getSeedContestantPhoto(item); var source = item.photo || seedPhoto;
    return '<span class="admin-contestant-photo">' + fallback + (source ? '<img src="' + esc(source) + '" data-photo-fallback="' + esc(seedPhoto) + '" alt="" loading="lazy">' : '') + '</span>';
  }
  function roundChips(rounds) { return rounds.length ? rounds.map(function (name) { return '<span class="admin-round-chip">' + esc(name) + '</span>'; }).join('') : '<span class="admin-muted">No rounds assigned</span>'; }
  function statusBadge(active) { return '<span class="admin-status admin-status-' + (active ? 'active' : 'inactive') + '"><span class="admin-status-dot"></span>' + (active ? 'Active' : 'Inactive') + '</span>'; }
  function render() {
    var search = document.getElementById('config-search'); var filter = document.getElementById('config-status-filter'); var term = (search ? search.value : '').toLowerCase(); var status = filter ? filter.value : 'all';
    var rows = state[kind].filter(function (item) { var hay = kind === 'contestants' ? [item.number, item.name, item.country].join(' ') : [item.displayNumber, item.name, item.email, item.phone].join(' '); return (!term || hay.toLowerCase().indexOf(term) !== -1) && (status === 'all' || item.status === status); });
    var head = kind === 'contestants' ? '<span>Contestant</span><span>Assigned rounds</span><span>Status</span><span>Action</span>' : '<span>Judge</span><span>Contact</span><span>Assigned rounds</span><span>Status</span><span>Action</span>';
    var body = rows.map(function (item) {
      var rounds = roundsFor(item);
      var active = item.status !== 'inactive';
      if (kind === 'contestants') {
        return '<article class="admin-config-row admin-contestant-row">' +
          '<div class="admin-contestant-identity">' + photo(item) + '<div class="admin-contestant-copy"><strong class="admin-contestant-name">#' + String(item.number).padStart(2, '0') + ' · ' + esc(item.name) + '</strong><span class="admin-contestant-country">' + esc(item.country) + '</span></div></div>' +
          '<div class="admin-round-summary">' + roundChips(rounds) + '</div>' + statusBadge(active) +
          '<button class="admin-btn admin-btn-small" type="button" data-master-edit="' + item.id + '">Edit</button></article>';
      }
      return '<article class="admin-config-row admin-master-row admin-judge-row">' +
        '<div class="admin-data-primary"><div class="admin-master-primary">' + avatar(item) + '<span class="admin-judge-identity"><span class="admin-data-name">Judge ' + esc(item.displayNumber) + ' · ' + esc(item.name) + '</span></span></div></div>' +
        '<div class="admin-judge-contact"><span>' + esc(item.email) + '</span><span>' + esc(item.phone) + '</span></div>' +
        '<div class="admin-round-summary admin-judge-rounds"><span class="admin-judge-rounds-label">Rounds</span>' + roundChips(rounds) + '</div>' +
        statusBadge(active) + '<button class="admin-btn admin-btn-small" type="button" data-master-edit="' + item.id + '">Edit</button></article>';
    }).join('');
    root.innerHTML = rows.length ? '<section class="admin-panel admin-config-list ' + (kind === 'contestants' ? 'admin-contestant-roster' : 'admin-judge-list') + '"><div class="admin-config-head">' + head + '</div>' + body + '</section>' : '<section class="admin-panel admin-state"><span class="admin-state-icon">○</span><h3>No ' + kind + ' found</h3><p>Try another search or add a new ' + (kind === 'contestants' ? 'contestant' : 'judge') + '.</p></section>';
  }
  root.addEventListener('error', function (event) {
    var image = event.target;
    if (!image.matches || !image.matches('.admin-contestant-photo img')) return;
    if (image.dataset.photoFallback && !image.dataset.photoRetried) { image.dataset.photoRetried = 'true'; image.src = image.dataset.photoFallback; }
    else image.hidden = true;
  }, true);
  function field(label, id, value, extra) { return '<div class="admin-form-field"><label class="admin-field-label" for="' + id + '">' + label + '</label><input class="admin-field" id="' + id + '" value="' + esc(value) + '" ' + (extra || '') + ' /></div>'; }
  function updatePhotoPreview() {
    var preview = document.getElementById('master-photo-preview'); if (!preview) return;
    var urlField = document.getElementById('master-photo');
    var url = urlField ? urlField.value.trim() : '';
    var source = pendingFilePhoto || url || currentDrawerPhoto;
    var nameField = document.getElementById('master-name');
    var numberField = document.getElementById('master-number');
    var name = nameField ? nameField.value.trim() : '';
    var number = numberField ? numberField.value.trim() : '';
    var words = name.split(/\s+/).filter(Boolean).slice(0, 2);
    preview.querySelector('.admin-photo-preview-initials').textContent = words.length ? words.map(function (word) { return word.charAt(0); }).join('').toUpperCase() : '—';
    document.getElementById('master-photo-preview-name').textContent = (number ? '#' + String(number).padStart(2, '0') + ' · ' : '') + (name || 'New contestant');
    document.getElementById('master-photo-preview-caption').textContent = pendingFilePhoto ? 'New photo preview' : url && url !== currentDrawerPhoto ? 'Photo URL preview' : source ? 'Current photo' : 'No photo selected';
    var image = preview.querySelector('img');
    if (!source) { image.removeAttribute('src'); image.hidden = true; return; }
    if (image.dataset.failedSource === source) { image.hidden = true; return; }
    if (image.getAttribute('src') !== source) { image.hidden = true; delete image.dataset.failedSource; image.src = source; }
    else image.hidden = image.dataset.loadedSource !== source;
  }
  function openDrawer(id) {
    var item = id ? state[kind].find(function (x) { return x.id === Number(id); }) : null; var isContestant = kind === 'contestants';
    photoSession += 1; pendingFilePhoto = ''; photoReading = false; currentDrawerPhoto = isContestant && item ? (item.photo || D.getSeedContestantPhoto(item)) : '';
    document.getElementById('admin-drawer-title').textContent = (item ? 'Edit ' : 'Add ') + (isContestant ? 'Contestant' : 'Judge');
    var body = isContestant
      ? '<section class="admin-photo-preview-field" aria-label="Contestant photo preview"><span class="admin-field-label">Photo preview</span><div class="admin-photo-preview-layout"><span class="admin-photo-preview" id="master-photo-preview"><span class="admin-photo-preview-initials" aria-hidden="true"></span><img alt="Contestant photo preview" hidden></span><div class="admin-photo-preview-meta"><strong id="master-photo-preview-name"></strong><span id="master-photo-preview-caption"></span></div></div></section>' +
        field('Number', 'master-number', item ? item.number : state.contestants.length + 1, 'type="number" min="1"') +
        field('Name', 'master-name', item ? item.name : '') +
        field('Country', 'master-country', item ? item.country : '') +
        field('Photo URL', 'master-photo', currentDrawerPhoto, 'type="text" placeholder="photos/contestant-01.jpg"') +
        '<div class="admin-form-field"><span class="admin-field-label">Choose Photo</span><div class="admin-photo-upload-row"><label class="admin-btn admin-photo-upload-button" for="master-photo-file" tabindex="0">Choose Photo</label><span class="admin-photo-file-name" id="master-photo-file-name">No file selected</span></div><input class="sr-only" id="master-photo-file" type="file" accept="image/*" aria-describedby="master-photo-file-name"></div>'
      : field('Display Number', 'master-display-number', item ? item.displayNumber : String(state.judges.length + 1).padStart(2, '0')) + field('Name', 'master-name', item ? item.name : '') + field('Email', 'master-email', item ? item.email : '', 'type="email"') + field('Phone', 'master-phone', item ? item.phone : '');
    body += '<div class="admin-form-field"><label class="admin-field-label" for="master-status">Status</label><select class="admin-field" id="master-status"><option value="active"' + (!item || item.status === 'active' ? ' selected' : '') + '>Active</option><option value="inactive"' + (item && item.status === 'inactive' ? ' selected' : '') + '>Inactive</option></select></div><p class="admin-master-form-note">Changes are stored locally in this prototype only.</p>';
    document.getElementById('admin-drawer-body').innerHTML = '<form id="master-form" class="admin-form-grid ' + (isContestant ? 'admin-contestant-form' : 'admin-judge-form') + '">' + body + '</form>';
    document.getElementById('admin-drawer-footer').innerHTML = '<button class="admin-btn" type="button" data-close-drawer>Cancel</button><button class="admin-btn admin-btn-primary" type="button" data-master-save>Save changes</button>';
    drawer.dataset.editId = item ? item.id : ''; drawer.hidden = false; document.getElementById('admin-drawer-body').scrollTop = 0;
    if (isContestant) updatePhotoPreview();
    document.getElementById('master-name').focus({ preventScroll: true });
  }
  function saveItem() {
    if (photoReading) return;
    var isContestant = kind === 'contestants'; var id = drawer.dataset.editId ? Number(drawer.dataset.editId) : (state[kind].reduce(function (max, item) { return Math.max(max, item.id); }, 0) + 1); var item = state[kind].find(function (x) { return x.id === id; }) || { id: id };
    if (isContestant) { item.number = Number(document.getElementById('master-number').value) || id; item.name = document.getElementById('master-name').value.trim() || 'Unnamed contestant'; item.country = document.getElementById('master-country').value.trim() || '—'; item.photo = pendingFilePhoto || document.getElementById('master-photo').value.trim() || currentDrawerPhoto; item.photoCleared = !item.photo; } else { item.displayNumber = document.getElementById('master-display-number').value.trim() || String(id).padStart(2, '0'); item.name = document.getElementById('master-name').value.trim() || 'Unnamed judge'; item.email = document.getElementById('master-email').value.trim(); item.phone = document.getElementById('master-phone').value.trim(); }
    item.status = document.getElementById('master-status').value; if (!state[kind].some(function (x) { return x.id === id; })) state[kind].push(item); saveState(item); drawer.hidden = true; render();
  }
  document.getElementById('config-search').addEventListener('input', render); document.getElementById('config-status-filter').addEventListener('change', render);
  drawer.addEventListener('input', function (event) { if (['master-photo', 'master-name', 'master-number'].indexOf(event.target.id) !== -1) updatePhotoPreview(); });
  drawer.addEventListener('change', function (event) {
    if (event.target.id !== 'master-photo-file' || !event.target.files || !event.target.files[0]) return;
    var file = event.target.files[0]; var session = photoSession; var reader = new FileReader();
    photoReading = true; drawer.querySelector('[data-master-save]').disabled = true;
    document.getElementById('master-photo-file-name').textContent = file.name;
    reader.onload = function () { if (session !== photoSession || drawer.hidden) return; photoReading = false; drawer.querySelector('[data-master-save]').disabled = false; pendingFilePhoto = reader.result; updatePhotoPreview(); };
    reader.onerror = function () { if (session !== photoSession || drawer.hidden) return; photoReading = false; drawer.querySelector('[data-master-save]').disabled = false; document.getElementById('master-photo-file-name').textContent = 'Could not read photo'; };
    reader.readAsDataURL(file);
  });
  drawer.addEventListener('error', function (event) {
    var image = event.target;
    if (image.matches && image.matches('#master-photo-preview img')) { image.dataset.failedSource = image.getAttribute('src') || ''; delete image.dataset.loadedSource; image.hidden = true; }
  }, true);
  drawer.addEventListener('load', function (event) {
    var image = event.target;
    if (image.matches && image.matches('#master-photo-preview img')) { image.dataset.loadedSource = image.getAttribute('src') || ''; image.hidden = false; }
  }, true);
  drawer.addEventListener('keydown', function (event) {
    if (event.target.matches('.admin-photo-upload-button') && (event.key === 'Enter' || event.key === ' ')) { event.preventDefault(); document.getElementById('master-photo-file').click(); }
  });
  drawer.addEventListener('submit', function (event) { if (event.target.id === 'master-form') { event.preventDefault(); saveItem(); } });
  document.addEventListener('click', function (event) { var target = event.target.closest('[data-master-open], [data-master-edit], [data-master-save]'); if (!target) return; if (target.matches('[data-master-open]')) openDrawer(); if (target.matches('[data-master-edit]')) openDrawer(target.dataset.masterEdit); if (target.matches('[data-master-save]')) saveItem(); });
  render();
})();
