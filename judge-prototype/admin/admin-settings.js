// Event-level prototype settings; persisted with the shared Admin configuration.
(function () {
  var D = window.KreenAdminDomain;
  var form = document.getElementById('admin-settings-form');
  if (!D || !form) return;
  var saved = D.getEventSettings();
  var toggles = form.querySelectorAll('[data-setting-toggle]');
  var error = document.getElementById('settings-error');
  var saveButton = document.getElementById('settings-save');
  var cancelButton = document.getElementById('settings-cancel');
  var saveState = document.getElementById('settings-save-state');
  function setToggle(button, enabled) {
    button.setAttribute('aria-checked', String(!!enabled));
    form.querySelector('[data-toggle-value="' + button.dataset.settingToggle + '"]').textContent = enabled ? 'ON' : 'OFF';
  }
  function fill(values) {
    ['eventName', 'eventYear', 'shortName', 'minScore', 'maxScore', 'step'].forEach(function (key) { form.elements[key].value = values[key]; });
    toggles.forEach(function (button) { setToggle(button, values[button.dataset.settingToggle]); });
    error.hidden = true;
    updateDirty();
  }
  function current() {
    var result = {};
    ['eventName', 'eventYear', 'shortName'].forEach(function (key) { result[key] = form.elements[key].value.trim(); });
    ['minScore', 'maxScore', 'step'].forEach(function (key) { result[key] = Number(form.elements[key].value); });
    toggles.forEach(function (button) { result[button.dataset.settingToggle] = button.getAttribute('aria-checked') === 'true'; });
    return result;
  }
  function updateDirty() {
    var dirty = JSON.stringify(current()) !== JSON.stringify(saved);
    saveButton.disabled = !dirty;
    cancelButton.disabled = !dirty;
    saveState.textContent = dirty ? 'Unsaved changes' : 'All changes saved';
    saveState.classList.toggle('is-unsaved', dirty);
  }
  function showError(message) { error.textContent = message; error.hidden = false; error.scrollIntoView({ block: 'nearest' }); }
  toggles.forEach(function (button) { button.addEventListener('click', function () { setToggle(button, button.getAttribute('aria-checked') !== 'true'); updateDirty(); }); });
  form.addEventListener('input', function () { error.hidden = true; updateDirty(); });
  cancelButton.addEventListener('click', function () { fill(saved); });
  form.addEventListener('submit', function (event) {
    event.preventDefault();
    var values = current();
    if (!values.eventName || !values.shortName || !/^\d{4}$/.test(values.eventYear)) { showError('Enter an event name, a short name, and a four-digit event year.'); return; }
    if (!form.elements.minScore.value || !form.elements.maxScore.value || !form.elements.step.value || !Number.isFinite(values.minScore) || !Number.isFinite(values.maxScore) || !Number.isFinite(values.step) || values.maxScore <= values.minScore || values.step <= 0 || values.step > values.maxScore - values.minScore) { showError('Enter a score scale with Max greater than Min and a positive step within that range.'); return; }
    if (!D.setEventSettings(values)) { showError('Settings could not be saved in this browser. Check available local storage.'); return; }
    saved = D.getEventSettings();
    document.querySelector('.admin-context-name').textContent = saved.eventName;
    document.querySelector('.admin-context-meta').textContent = saved.eventYear;
    fill(saved);
  });
  document.getElementById('settings-reset').addEventListener('click', function () {
    if (!window.confirm('Reset only Event Settings to their defaults? Contestants, rounds, scores, results, and advancement will stay unchanged.')) return;
    if (!D.resetEventSettings()) { showError('Settings could not be reset in this browser.'); return; }
    saved = D.getEventSettings();
    document.querySelector('.admin-context-name').textContent = saved.eventName;
    document.querySelector('.admin-context-meta').textContent = saved.eventYear;
    fill(saved);
  });
  fill(saved);
})();
