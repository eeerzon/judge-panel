// Finalized-result advancement is a separate, explicit Admin decision.
(function () {
  var app = document.querySelector('.admin-app'); if (!app || app.dataset.adminPage !== 'advancement') return;
  var D = window.KreenAdminDomain, roundId = Number(new URLSearchParams(location.search).get('round') || 1);
  var source = D.getRound(roundId), target = D.getNextRound(roundId);
  var slot = window.renderRoundWorkspace({ roundId: roundId, activeTab: 'results', pageTitle: 'Advancement Selection', pageDescription: source && target ? source.name + ' → ' + target.name : 'Select the next round contestants.', contentTarget: 'admin-page-content' });
  if (!slot) return;
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>'"]/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[c]; }); }
  var result = D.calculateRoundResults(roundId);
  if (!source || !target || !result.available || !result.finalized || D.getAdvancement(roundId)) { slot.innerHTML = '<section class="admin-panel admin-state"><h3>Advancement unavailable</h3><p>Finalize this round before selecting contestants, or review its confirmed advancement.</p><a class="admin-btn" href="round-results.html?round=' + roundId + '">Back to Results</a></section>'; return; }
  var count = Number(source.advancementCount || 0), defaults = D.getDefaultAdvancementIds(roundId), selected = defaults.slice();
  var cutoffTie = D.hasAdvancementCutoffTie(roundId);
  slot.innerHTML = '<a class="admin-round-back" href="round-results.html?round=' + roundId + '">← Official Results</a><section class="admin-panel admin-advancement-intro"><div><p class="admin-eyebrow">' + esc(source.name) + ' → ' + esc(target.name) + '</p><h3>Choose ' + count + ' advancing contestants</h3><p>Top ' + count + ' is preselected from the finalized result. Review before confirming; the official result will not change.</p></div><strong id="advancement-count"></strong></section>' +
    (cutoffTie ? '<div class="admin-warning"><strong>Tie at qualification cut.</strong> Contestants share the cutoff score. Make an explicit selection and explain the decision; official ranks stay tied.</div>' : '') +
    '<section class="admin-panel admin-advancement-list">' + result.items.map(function (item) { return '<label class="admin-advancement-row"><input type="checkbox" data-advance-id="' + item.contestantId + '" ' + (selected.indexOf(item.contestantId) !== -1 ? 'checked' : '') + '><strong class="admin-result-rank">' + item.rank + (item.tied ? '<small>TIED</small>' : '') + '</strong><span><strong>#' + String(item.number).padStart(2, '0') + ' · ' + esc(item.name) + '</strong><small>' + esc(item.country) + '</small></span><strong class="admin-result-score">' + Number(item.combinedScore).toFixed(2) + '</strong></label>'; }).join('') + '</section><section class="admin-panel admin-advancement-reason" id="advancement-reason-wrap" hidden><label class="admin-field-label" for="advancement-reason">Reason for manual selection *</label><textarea class="admin-field admin-textarea" id="advancement-reason" placeholder="For example, a qualified contestant withdrew before the next round."></textarea></section><p class="admin-field-error" id="advancement-error" hidden></p><div class="admin-page-actions"><button class="admin-btn admin-btn-primary" data-advancement-preview>Preview Advancement</button></div><div id="advancement-preview"></div>';
  function currentIds() { return Array.from(slot.querySelectorAll('[data-advance-id]:checked')).map(function (input) { return Number(input.dataset.advanceId); }); }
  function reason() { return slot.querySelector('#advancement-reason').value.trim(); }
  function needsReason(ids) { return cutoffTie || ids.some(function (id) { return defaults.indexOf(id) === -1; }) || ids.length !== defaults.length; }
  function update() { selected = currentIds(); slot.querySelector('#advancement-count').textContent = selected.length + ' / ' + count + ' selected'; slot.querySelector('#advancement-reason-wrap').hidden = !needsReason(selected); slot.querySelector('#advancement-preview').innerHTML = ''; slot.querySelector('#advancement-error').hidden = true; }
  function names(ids) { return result.items.filter(function (item) { return ids.indexOf(item.contestantId) !== -1; }).map(function (item) { return '<li><span>#' + String(item.number).padStart(2, '0') + ' · ' + esc(item.name) + '</span><strong>Rank ' + item.rank + '</strong></li>'; }).join(''); }
  slot.addEventListener('change', function (event) { if (event.target.matches('[data-advance-id]')) update(); });
  slot.addEventListener('click', function (event) {
    if (event.target.closest('[data-advancement-preview]')) {
      var ids = currentIds(), check = D.validateAdvancement(roundId, ids, reason());
      if (!check.ok) { var error = slot.querySelector('#advancement-error'); error.textContent = check.message; error.hidden = false; return; }
      var notSelected = result.items.map(function (item) { return item.contestantId; }).filter(function (id) { return ids.indexOf(id) === -1; });
      slot.querySelector('#advancement-preview').innerHTML = '<section class="admin-panel admin-advancement-preview"><p class="admin-eyebrow">Preview · ' + esc(source.name) + ' → ' + esc(target.name) + '</p><h3>Advancing: ' + ids.length + '</h3><ol>' + names(ids) + '</ol><h3>Not advancing: ' + notSelected.length + '</h3><ol>' + names(notSelected) + '</ol>' + (check.manual ? '<p class="admin-lock-note">Manual selection · Reason: ' + esc(reason()) + '</p>' : '') + '<div class="admin-modal-actions"><button class="admin-btn" data-preview-cancel>Cancel</button><button class="admin-btn admin-btn-primary" data-advancement-confirm-open>Confirm Advancement</button></div></section>';
    } else if (event.target.closest('[data-preview-cancel]')) slot.querySelector('#advancement-preview').innerHTML = '';
    else if (event.target.closest('[data-advancement-confirm-open]')) {
      var modal = document.createElement('div'); modal.id = 'advancement-confirm-modal'; modal.className = 'admin-modal-backdrop'; modal.innerHTML = '<section class="admin-modal" role="dialog" aria-modal="true"><h2>Advance ' + selected.length + ' contestants to ' + esc(target.name) + '?</h2><p>This creates their target-round assignment. Official ' + esc(source.name) + ' results will not change.</p><div class="admin-modal-actions"><button class="admin-btn" data-advancement-cancel>Cancel</button><button class="admin-btn admin-btn-primary" data-advancement-commit>Confirm Advancement</button></div></section>'; document.body.appendChild(modal); modal.querySelector('[data-advancement-cancel]').focus();
    }
  });
  document.addEventListener('click', function (event) {
    if (event.target.closest('[data-advancement-cancel]')) document.getElementById('advancement-confirm-modal').remove();
    if (event.target.closest('[data-advancement-commit]')) { var check = D.confirmAdvancement(roundId, selected, reason()); if (check.ok) location.href = 'round.html?id=' + target.id; else { document.getElementById('advancement-confirm-modal').remove(); var error = slot.querySelector('#advancement-error'); error.textContent = check.message; error.hidden = false; } }
  });
  update();
})();
