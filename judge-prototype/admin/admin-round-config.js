// Round-specific contestant, judge, and criteria configuration.
(function () {
  var app = document.querySelector('.admin-app');
  var DATA = window.KreenAdminData;
  var D = window.KreenAdminDomain;
  if (!app || !DATA || !D || !window.renderRoundWorkspace) return;
  var page = app.dataset.configPage;
  if (['round-contestants', 'round-judges', 'criteria'].indexOf(page) === -1) return;
  var roundId = Number(new URLSearchParams(location.search).get('round') || 1);
  var round = DATA.getRoundById(roundId);
  if (!round) return;
  var locked = round.status !== 'draft';
  var contestantSelections = {};
  var pageMap = {
    'round-contestants': ['contestants', 'Contestants', 'Choose which event contestants participate in this round.'],
    'round-judges': ['judges', 'Judges', 'Assign event judges and mark required participation.'],
    criteria: ['criteria', 'Criteria', 'Configure the scoring hierarchy and effective scored weight.']
  };
  var pageInfo = pageMap[page];
  var slot = window.renderRoundWorkspace({ roundId: roundId, activeTab: pageInfo[0], pageTitle: pageInfo[1], pageDescription: pageInfo[2], contentTarget: '#admin-page-content' });
  if (!slot) return;
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>\'"]/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[c]; }); };
  function contestantPhoto(item) {
    var initials = (item.name || '?').split(/\s+/).slice(0, 2).map(function (word) { return word.charAt(0); }).join('').toUpperCase();
    var seedPhoto = D.getSeedContestantPhoto(item); var source = item.photo || seedPhoto;
    return '<span class="admin-contestant-photo admin-round-contestant-photo"><span class="admin-contestant-photo-fallback">' + esc(initials) + '</span>' + (source ? '<img src="' + esc(source) + '" data-photo-fallback="' + esc(seedPhoto) + '" alt="" loading="lazy">' : '') + '</span>';
  }
  slot.addEventListener('error', function (event) {
    var image = event.target;
    if (!image.matches || !image.matches('.admin-contestant-photo img')) return;
    if (image.dataset.photoFallback && !image.dataset.photoRetried) { image.dataset.photoRetried = 'true'; image.src = image.dataset.photoFallback; }
    else image.hidden = true;
  }, true);
  var lockNote = '<p class="admin-lock-note ' + (locked ? 'is-locked' : '') + '">' + (locked ? 'Round configuration is locked while judging is open.' : 'Draft configuration can be edited before opening the round.') + '</p>';
  function readiness() {
    var state = D.getRoundReadiness(roundId);
    return '<section class="admin-panel admin-readiness-summary"><div><strong>' + state.judgesAssigned + '</strong><span>Judges assigned</span></div><div><strong>' + state.requiredJudges + '</strong><span>Required judges</span></div><div><strong>' + state.requiredSubmitted + ' / ' + state.requiredJudges + '</strong><span>Required submissions</span></div><div><strong>' + state.effectiveScoredWeight + '%</strong><span>Effective scored weight</span></div></section>';
  }
  function contestantContent() {
    var all = D.getContestants();
    var advancement = D.getAdvancementForTarget(roundId); var source = advancement && D.getRound(advancement.sourceRoundId);
    slot.innerHTML = lockNote + (advancement ? '<p class="admin-lock-note">Source: Advanced from ' + esc(source.name) + '. Any Draft-round adjustment requires a reason; the official source result stays unchanged.</p><div id="advancement-assignment-warning"></div>' : '') + '<p class="admin-assignment-count"><strong id="round-contestant-count"></strong> assigned</p>' + readiness() + '<section class="admin-panel"><div class="admin-assignment-toolbar"><div class="admin-search-wrap"><span class="admin-search-icon">⌕</span><label class="sr-only" for="round-contestant-search">Search contestants</label><input class="admin-field" id="round-contestant-search" type="search" placeholder="Search number, name, or country"></div><div class="admin-assignment-actions"><button class="admin-btn admin-btn-small" data-select-all ' + (locked ? 'disabled' : '') + '>Select All</button><button class="admin-btn admin-btn-small" data-clear-all ' + (locked ? 'disabled' : '') + '>Clear Selection</button><button class="admin-btn admin-btn-primary admin-btn-small" data-apply-assignment="add" ' + (locked ? 'disabled' : '') + '>Add Selected</button><button class="admin-btn admin-btn-danger admin-btn-small" data-apply-assignment="remove" ' + (locked ? 'disabled' : '') + '>Remove Selected</button></div></div><div class="admin-assignment-list" id="round-contestant-list"></div></section>';
    function rows() {
      var assignedIds = D.getRoundContestants(roundId).map(function (item) { return Number(item.id); });
      var term = (document.getElementById('round-contestant-search').value || '').toLowerCase();
      var list = all.filter(function (item) { return [item.number, item.name, item.country].join(' ').toLowerCase().indexOf(term) !== -1; });
      document.getElementById('round-contestant-list').innerHTML = list.map(function (item) {
        var id = Number(item.id); var assigned = assignedIds.indexOf(id) !== -1;
        return '<article class="admin-assignment-card admin-contestant-assignment"><label class="admin-assignment-select"><input type="checkbox" data-contestant-select="' + id + '" ' + (contestantSelections[id] ? 'checked' : '') + (locked ? ' disabled' : '') + ' aria-label="Select ' + esc(item.name) + '"><span class="sr-only">Select contestant</span></label><span class="admin-assignment-person admin-contestant-identity">' + contestantPhoto(item) + '<span class="admin-contestant-copy"><strong class="admin-contestant-name">#' + String(item.number).padStart(2, '0') + ' · ' + esc(item.name) + '</strong><small class="admin-contestant-country">' + esc(item.country) + '</small></span></span><span class="admin-toggle-state ' + (assigned ? 'is-assigned' : '') + '">' + (assigned ? 'Assigned' : 'Unassigned') + '</span></article>';
      }).join('');
      document.getElementById('round-contestant-count').textContent = assignedIds.length + ' of ' + all.length;
      if (advancement) document.getElementById('advancement-assignment-warning').innerHTML = assignedIds.length !== advancement.selectedContestantIds.length || assignedIds.some(function (id) { return advancement.selectedContestantIds.indexOf(id) === -1; }) ? '<p class="admin-warning">Current contestant assignment differs from confirmed advancement. Adjustment reasons are retained in history.</p>' : '';
    }
    rows();
    document.getElementById('round-contestant-search').addEventListener('input', rows);
    return rows;
  }
  function judgeContent() {
    var all = D.getJudges();
    slot.innerHTML = lockNote + readiness() + '<section class="admin-panel"><div class="admin-assignment-toolbar"><strong>Round judge assignments</strong><span class="admin-muted">Required status applies only to assigned judges.</span></div><div class="admin-assignment-list" id="round-judge-list"></div></section>';
    function render() {
      var assigned = D.getRoundJudges(roundId);
      document.getElementById('round-judge-list').innerHTML = all.map(function (judge) {
        var assignment = assigned.find(function (item) { return Number(item.judgeId) === Number(judge.id); });
        var assignmentState = assignment ? assignment.assignmentStatus : 'unassigned';
        var isAssigned = assignmentState === 'assigned';
        var requiredLabel = assignment && assignment.required ? 'Required' : 'Optional';
        return '<article class="admin-assignment-card admin-judge-card"><span class="admin-assignment-person"><strong>Judge ' + esc(judge.displayNumber) + ' · ' + esc(judge.name) + '</strong><small>' + esc(judge.email) + ' · ' + esc(judge.phone) + '</small></span><label class="admin-required-toggle"><input type="checkbox" data-judge-assign="' + judge.id + '" ' + (isAssigned ? 'checked' : '') + (locked ? ' disabled' : '') + '> Assigned</label><label class="admin-required-toggle"><input type="checkbox" data-judge-required="' + judge.id + '" ' + (assignment && assignment.required ? 'checked' : '') + ((!isAssigned || locked) ? ' disabled' : '') + '> ' + requiredLabel + '</label><span class="admin-status admin-status-' + (isAssigned ? 'assigned' : assignmentState === 'excused' ? 'excused' : assignmentState === 'removed' ? 'removed' : 'unassigned') + '"><span class="admin-status-dot"></span>' + esc(assignmentState.charAt(0).toUpperCase() + assignmentState.slice(1)) + '</span></article>';
      }).join('');
      slot.querySelectorAll('[data-judge-assign]').forEach(function (input) { input.addEventListener('change', function () { D.setJudgeAssignment(roundId, Number(input.dataset.judgeAssign), input.checked); render(); }); });
      slot.querySelectorAll('[data-judge-required]').forEach(function (input) { input.addEventListener('change', function () { D.setJudgeRequired(roundId, Number(input.dataset.judgeRequired), input.checked); render(); }); });
    }
    render();
  }
  function criteriaContent() {
    var criteria = D.getCriteria(roundId);
    slot.innerHTML = lockNote + '<div id="criteria-weight-summary"></div><section class="admin-panel"><div class="admin-assignment-toolbar"><strong>Scoring hierarchy</strong><button class="admin-btn admin-btn-primary admin-btn-small" data-criterion-add ' + (locked ? 'disabled' : '') + '>+ Add Criterion</button></div><div class="admin-criteria-list" id="criteria-list"></div></section>';
    function render() {
      criteria = D.getCriteria(roundId);
      var total = D.getEffectiveScoredWeight(criteria);
      var message = total === 100 ? '100% ✓' : total < 100 ? total + '% → ' + (100 - total) + '% remaining' : total + '% → exceeds 100%';
      document.getElementById('criteria-weight-summary').innerHTML = readiness() + '<p class="admin-weight-callout ' + (total === 100 ? 'is-valid' : 'is-invalid') + '">' + message + '</p>';
      document.getElementById('criteria-list').innerHTML = criteria.slice().sort(function (a, b) { return a.sequence - b.sequence; }).map(function (item) {
        var parent = item.parentId && criteria.find(function (x) { return String(x.id) === String(item.parentId); });
        return '<article class="admin-criterion-row ' + (item.isParent ? 'is-parent' : '') + '"><div><strong>' + (item.isParent ? '▾ ' : parent ? '↳ ' : '') + esc(item.name) + '</strong><small>' + (parent ? esc(parent.name) + ' · ' : '') + (item.isScored ? item.minScore + '–' + item.maxScore + ' · Step ' + item.step : 'Non-scored') + (item.required ? ' · Required' : '') + '</small></div><span>' + (item.isScored ? item.weight + '%' : '—') + '</span><span class="admin-status admin-status-' + (item.isScored ? 'scored' : 'non-scored') + '"><span class="admin-status-dot"></span>' + (item.isScored ? 'Scored' : 'Non-scored') + '</span><button class="admin-btn admin-btn-small" data-criterion-edit="' + esc(item.id) + '" ' + (locked ? 'disabled' : '') + '>Edit</button></article>';
      }).join('');
    }
    function form(item) {
      var settings = D.getEventSettings();
      item = item || { name: '', parentId: '', weight: 0, minScore: settings.minScore, maxScore: settings.maxScore, step: settings.step, required: settings.defaultCriterionRequired, isScored: true, sequence: criteria.length + 1 };
      var parents = criteria.filter(function (x) { return x.isParent && String(x.id) !== String(item.id); }).map(function (x) { return '<option value="' + esc(x.id) + '" ' + (String(item.parentId) === String(x.id) ? 'selected' : '') + '>' + esc(x.name) + '</option>'; }).join('');
      return '<form id="criterion-form" class="admin-form-grid"><div class="admin-form-field"><label class="admin-field-label" for="criterion-name">Name</label><input class="admin-field" id="criterion-name" value="' + esc(item.name) + '" required></div><div class="admin-form-field"><label class="admin-field-label" for="criterion-parent">Parent</label><select class="admin-field" id="criterion-parent"><option value="">None</option>' + parents + '</select></div><div class="admin-form-field"><label class="admin-field-label" for="criterion-weight">Weight %</label><input class="admin-field" id="criterion-weight" type="number" min="0" value="' + Number(item.weight || 0) + '"></div><div class="admin-form-field"><label class="admin-field-label" for="criterion-min">Min score</label><input class="admin-field" id="criterion-min" type="number" value="' + Number(item.minScore || 0) + '"></div><div class="admin-form-field"><label class="admin-field-label" for="criterion-max">Max score</label><input class="admin-field" id="criterion-max" type="number" value="' + Number(item.maxScore || 0) + '"></div><div class="admin-form-field"><label class="admin-field-label" for="criterion-step">Step</label><input class="admin-field" id="criterion-step" type="number" step="0.01" value="' + Number(item.step || 0.25) + '"></div><label class="admin-toggle-row"><span>Required</span><input id="criterion-required" type="checkbox" ' + (item.required ? 'checked' : '') + '></label><label class="admin-toggle-row"><span>Scored criterion</span><input id="criterion-scored" type="checkbox" ' + (item.isScored ? 'checked' : '') + '></label><label class="admin-toggle-row"><span>Parent group</span><input id="criterion-parent-group" type="checkbox" ' + (item.isParent ? 'checked' : '') + '></label><div class="admin-form-field"><label class="admin-field-label" for="criterion-sequence">Sequence</label><input class="admin-field" id="criterion-sequence" type="number" min="1" value="' + Number(item.sequence || 1) + '"></div></form>';
    }
    function openForm(id) {
      var item = id == null ? null : criteria.find(function (x) { return String(x.id) === String(id); });
      var panel = document.getElementById('round-config-drawer');
      if (!panel) { panel = document.createElement('div'); panel.id = 'round-config-drawer'; panel.className = 'admin-drawer-backdrop'; panel.hidden = true; panel.innerHTML = '<aside class="admin-drawer" role="dialog" aria-modal="true"><header class="admin-drawer-header"><h2 id="round-config-drawer-title"></h2><button class="admin-icon-btn" type="button" data-round-close>×</button></header><div class="admin-drawer-body" id="round-config-drawer-body"></div><footer class="admin-drawer-footer" id="round-config-drawer-footer"></footer></aside>'; document.body.appendChild(panel); }
      panel.dataset.criterionId = item ? item.id : '';
      panel.querySelector('#round-config-drawer-title').textContent = item ? 'Edit Criterion' : 'Add Criterion';
      panel.querySelector('#round-config-drawer-body').innerHTML = form(item);
      panel.querySelector('#round-config-drawer-footer').innerHTML = '<button class="admin-btn" type="button" data-round-close>Cancel</button><button class="admin-btn admin-btn-primary" type="button" data-criterion-save>Save changes</button>';
      panel.hidden = false;
    }
    render();
    slot.addEventListener('click', function (event) {
      var target = event.target.closest('[data-criterion-add], [data-criterion-edit]'); if (!target) return;
      openForm(target.hasAttribute('data-criterion-edit') ? target.dataset.criterionEdit : null);
    });
    document.addEventListener('click', function (event) {
      var target = event.target.closest('[data-criterion-save], [data-round-close]'); if (!target) return;
      var panel = document.getElementById('round-config-drawer');
      if (target.matches('[data-round-close]')) { panel.hidden = true; return; }
      var current = D.getCriteria(roundId); var id = panel.dataset.criterionId;
      var item = current.find(function (x) { return String(x.id) === String(id); });
      if (!item) { item = { id: roundId + '-custom-' + Date.now(), roundId: roundId }; current.push(item); }
      item.name = document.getElementById('criterion-name').value.trim() || 'Untitled criterion';
      item.parentId = document.getElementById('criterion-parent').value || null;
      item.weight = Number(document.getElementById('criterion-weight').value || 0);
      item.minScore = Number(document.getElementById('criterion-min').value || 0);
      item.maxScore = Number(document.getElementById('criterion-max').value || 0);
      item.step = Number(document.getElementById('criterion-step').value || 0.25);
      item.required = document.getElementById('criterion-required').checked;
      var wasParent = item.isParent;
      item.isParent = document.getElementById('criterion-parent-group').checked;
      if (item.isParent) item.parentId = null;
      if (wasParent && !item.isParent) current.forEach(function (child) { if (String(child.parentId) === String(item.id)) child.parentId = null; });
      item.isScored = !item.isParent && document.getElementById('criterion-scored').checked;
      if (item.isParent) item.weight = 0;
      item.sequence = Number(document.getElementById('criterion-sequence').value || current.length);
      D.setCriteria(roundId, current); panel.hidden = true; render();
    });
  }
  var contestantRender;
  if (page === 'round-contestants') contestantRender = contestantContent();
  if (page === 'round-judges') judgeContent();
  if (page === 'criteria') criteriaContent();
  if (page === 'round-contestants') {
    slot.addEventListener('click', function (event) {
      var target = event.target.closest('[data-select-all], [data-clear-all], [data-apply-assignment]'); if (!target || locked) return;
      if (target.matches('[data-select-all]')) { slot.querySelectorAll('[data-contestant-select]').forEach(function (input) { input.checked = true; selectedValue(input, true); }); }
      if (target.matches('[data-clear-all]')) { contestantSelections = {}; contestantRender(); }
      if (target.matches('[data-apply-assignment]')) {
        var selectedIds = Object.keys(contestantSelections).filter(function (id) { return contestantSelections[id]; }).map(Number);
        var ids = D.getRoundContestants(roundId).map(function (item) { return Number(item.id); });
        selectedIds.forEach(function (id) { ids = target.dataset.applyAssignment === 'add' ? (ids.indexOf(id) < 0 ? ids.concat(id) : ids) : ids.filter(function (existing) { return existing !== id; }); });
        var advancement = D.getAdvancementForTarget(roundId);
        if (advancement) {
          var modal = document.createElement('div'); modal.id = 'assignment-reason-modal'; modal.className = 'admin-modal-backdrop'; modal.innerHTML = '<section class="admin-modal" role="dialog" aria-modal="true"><h2>Adjust advanced contestants?</h2><p>Explain the withdrawal or replacement. Official source ranking remains unchanged.</p><label class="admin-field-label" for="assignment-reason">Reason *</label><textarea class="admin-field admin-textarea" id="assignment-reason" required></textarea><div class="admin-modal-actions"><button class="admin-btn" data-assignment-cancel>Cancel</button><button class="admin-btn admin-btn-primary" data-assignment-confirm>Save Adjustment</button></div></section>'; modal.pendingIds = ids; document.body.appendChild(modal); modal.querySelector('textarea').focus();
        } else { D.setRoundContestantAssignments(roundId, ids); contestantSelections = {}; contestantRender(); }
      }
    });
  }
  document.addEventListener('click', function (event) {
    var modal = document.getElementById('assignment-reason-modal'); if (!modal) return;
    if (event.target.closest('[data-assignment-cancel]')) modal.remove();
    if (event.target.closest('[data-assignment-confirm]')) { var reason = document.getElementById('assignment-reason').value.trim(); if (!reason) { document.getElementById('assignment-reason').focus(); return; } if (D.adjustAdvancementAssignment(roundId, modal.pendingIds, reason)) { modal.remove(); contestantSelections = {}; contestantRender(); } }
  });
  function selectedValue(input, value) { contestantSelections[Number(input.dataset.contestantSelect)] = value; }
  slot.addEventListener('change', function (event) { if (event.target.matches('[data-contestant-select]')) selectedValue(event.target, event.target.checked); });
})();
