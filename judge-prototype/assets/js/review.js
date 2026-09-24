// review.html — reachable any time, complete or not (section 8 of the
// refactor brief: Review must never be blocked, it's the screen that shows
// what's still missing). Submission itself is still gated on completeness
// inside state.js's submitJudging().

(function () {
  const DATA = window.JudgePrototypeData;
  const S = window.JudgeState;
  const Nav = window.JudgeNav;

  window.JudgeChrome.init();
  const round = Nav.guardAssignedRound();
  if (!round) return;
  const contestants = DATA.getRoundContestants(round.id);

  document.getElementById('review-round').textContent = round.name;

  const backBtn = document.getElementById('review-back');
  const summaryPanel = document.getElementById('review-summary-panel');
  const filterPills = document.querySelectorAll('#review-filter-group .filter-pill');
  const countAllEl = document.getElementById('review-count-all');
  const countAttentionEl = document.getElementById('review-count-attention');
  const countScoredEl = document.getElementById('review-count-scored');
  const listEl = document.getElementById('review-list');
  const footerEl = document.getElementById('review-footer');

  const submitModalBackdrop = document.getElementById('submit-modal-backdrop');
  const submitModalBody = document.getElementById('submit-modal-body');
  const submitModalConfirmBody = document.getElementById('submit-modal-confirm-body');
  const submitModalFailedBody = document.getElementById('submit-modal-failed-body');
  const modalCancelBtn = document.getElementById('modal-cancel');
  const modalConfirmBtn = document.getElementById('modal-confirm');
  const modalFailedRetryBtn = document.getElementById('modal-failed-retry');

  backBtn.addEventListener('click', function () { Nav.goToContestants(round.id); });

  let reviewFilter = 'all';

  function statusMeta(status, info) {
    if (status === 'scored') return { className: 'status-scored', label: '✓ Scored' };
    if (status === 'draft') return { className: 'status-draft', label: 'Draft · ' + info.scoredCount + ' / ' + info.total + ' criteria' };
    return { className: 'status-not-started', label: 'Not Scored' };
  }

  function render() {
    renderSummary();
    updateFilterCounts();
    renderList();
    renderFooter();
  }

  function renderSummary() {
    const counts = S.countByStatus();
    const allScored = counts.scored === counts.total;
    const pct = Math.round((counts.scored / counts.total) * 100);

    summaryPanel.classList.toggle('is-ready', allScored && !S.isSubmitted());

    let noteHtml;
    if (S.isSubmitted()) {
      noteHtml = '<p class="review-summary-note">Judging submitted. These scores are locked and can no longer be edited.</p>';
    } else if (allScored) {
      noteHtml = '<p class="review-summary-note">All contestants have been scored. Review your entries before submitting.</p>';
    } else {
      const remaining = counts.total - counts.scored;
      noteHtml = '<p class="review-summary-note">' + remaining + ' contestant' + (remaining === 1 ? '' : 's') +
        ' still need' + (remaining === 1 ? 's' : '') + ' attention. Complete all scores before final submission.</p>';
    }

    summaryPanel.innerHTML =
      '<div class="review-summary-top">' +
        '<span class="review-summary-count">' + counts.scored + ' / ' + counts.total + ' contestants scored</span>' +
      '</div>' +
      '<div class="review-progress-track"><div class="review-progress-fill" style="width:' + pct + '%"></div></div>' +
      noteHtml +
      '<div class="review-status-counts">' +
        '<span class="review-status-count review-status-count-scored"><span class="status-dot" aria-hidden="true"></span>✓ Scored ' + counts.scored + '</span>' +
        '<span class="review-status-count review-status-count-draft"><span class="status-dot" aria-hidden="true"></span>Draft ' + counts.draft + '</span>' +
        '<span class="review-status-count review-status-count-not-started"><span class="status-dot" aria-hidden="true"></span>Not Scored ' + counts.notStarted + '</span>' +
      '</div>';
  }

  function updateFilterCounts() {
    const counts = S.countByStatus();
    countAllEl.textContent = counts.total;
    countAttentionEl.textContent = counts.draft + counts.notStarted;
    countScoredEl.textContent = counts.scored;
  }

  function matchesFilter(contestant, filter) {
    const status = S.getContestantStatus(contestant.id).status;
    if (filter === 'all') return true;
    if (filter === 'scored') return status === 'scored';
    if (filter === 'attention') return status !== 'scored';
    return true;
  }

  function buildRow(contestant) {
    const info = S.getContestantStatus(contestant.id);
    const status = statusMeta(info.status, info);
    const numberLabel = '#' + String(contestant.number).padStart(2, '0');
    const hue = DATA.photoHues[(contestant.number - 1) % DATA.photoHues.length];
    const fallbackBg = 'linear-gradient(160deg, hsl(' + hue + ', 32%, 22%), hsl(' + hue + ', 28%, 12%))';

    const row = document.createElement('button');
    row.type = 'button';
    row.className = 'review-row';
    row.setAttribute('role', 'listitem');
    row.setAttribute('aria-label', numberLabel + ' ' + contestant.name + ', ' + contestant.country + ', ' + status.label);

    const substatusHtml = info.status === 'scored'
      ? ''
      : '<span class="review-row-substatus is-' + info.status + '">' + status.label + '</span>';

    let actionColHtml;
    if (info.status === 'scored') {
      actionColHtml = '<span class="review-row-badge">✓ Scored</span>';
    } else if (S.isSubmitted()) {
      actionColHtml = '';
    } else if (info.status === 'draft') {
      actionColHtml = '<span class="review-row-action">Continue</span>';
    } else {
      actionColHtml = '<span class="review-row-action">Score</span>';
    }

    const total = S.calculateContestantTotal(contestant.id);
    const scoreValueHtml = total === null
      ? '<span class="review-row-score-value is-empty">—</span>'
      : '<span class="review-row-score-value">' + total.toFixed(2) + '</span>';

    row.innerHTML =
      '<div class="review-row-identity">' +
        '<div class="review-row-photo" style="background: ' + fallbackBg + ';">' +
          '<img src="' + contestant.photo + '" alt="" loading="lazy" onerror="this.style.display=\'none\';" />' +
        '</div>' +
        '<div class="review-row-main">' +
          '<div class="review-row-name-line">' +
            '<span class="review-row-number">' + numberLabel + '</span>' +
            '<span class="review-row-name">' + contestant.name + '</span>' +
          '</div>' +
          '<span class="review-row-country">' + contestant.country + '</span>' +
          substatusHtml +
        '</div>' +
      '</div>' +
      '<div class="review-row-score">' +
        '<span class="review-row-score-label">Total Score</span>' +
        scoreValueHtml +
        '<span class="review-row-score-max">/ 100</span>' +
      '</div>' +
      '<div class="review-row-action-col">' + actionColHtml + '</div>';

    row.addEventListener('click', function () {
      Nav.goToScoring(contestant.id, 'review');
    });

    return row;
  }

  function renderList() {
    listEl.innerHTML = '';
    const visible = contestants.filter(function (c) { return matchesFilter(c, reviewFilter); });
    if (visible.length === 0) {
      const empty = document.createElement('p');
      empty.className = 'review-empty-state';
      empty.textContent = 'No contestants in this filter.';
      listEl.appendChild(empty);
      return;
    }
    visible.forEach(function (c) { listEl.appendChild(buildRow(c)); });
  }

  filterPills.forEach(function (pill) {
    pill.addEventListener('click', function () {
      reviewFilter = pill.dataset.reviewFilter;
      filterPills.forEach(function (p) {
        const isActive = p === pill;
        p.classList.toggle('is-active', isActive);
        p.setAttribute('aria-selected', String(isActive));
      });
      renderList();
    });
  });

  function goToFirstIncomplete() {
    const target = contestants.find(function (c) { return S.getContestantStatus(c.id).status !== 'scored'; });
    if (target) Nav.goToScoring(target.id, 'review');
  }

  function renderFooter() {
    const counts = S.countByStatus();
    const allScored = counts.scored === counts.total;

    if (S.isSubmitted()) {
      footerEl.innerHTML =
        '<div class="review-footer-inner">' +
          '<span class="review-footer-note">Judging submitted — scores are locked.</span>' +
        '</div>';
      return;
    }

    if (allScored) {
      footerEl.innerHTML =
        '<div class="review-footer-inner">' +
          '<div class="review-footer-text">' +
            '<span class="review-footer-count">' + counts.total + ' / ' + counts.total + ' completed</span>' +
            '<span class="review-footer-hint">✓ Ready to submit</span>' +
          '</div>' +
          '<button type="button" class="review-footer-btn is-ready" id="review-submit-btn">Submit Judging</button>' +
        '</div>';
    } else {
      const remaining = counts.total - counts.scored;
      footerEl.innerHTML =
        '<div class="review-footer-inner">' +
          '<div class="review-footer-text">' +
            '<span class="review-footer-count">' + remaining + ' contestant' + (remaining === 1 ? '' : 's') + ' remaining</span>' +
            '<span class="review-footer-hint">Complete all contestants before submitting.</span>' +
          '</div>' +
          '<button type="button" class="review-footer-btn" id="review-complete-remaining-btn">Complete Remaining Scores</button>' +
        '</div>';
    }
  }

  footerEl.addEventListener('click', function (e) {
    if (e.target.id === 'review-submit-btn') openSubmitModal();
    else if (e.target.id === 'review-complete-remaining-btn') goToFirstIncomplete();
  });

  // ---- Submit confirmation modal ----

  function showModalConfirmBody() {
    submitModalConfirmBody.hidden = false;
    submitModalFailedBody.hidden = true;
  }
  function showModalFailedBody() {
    submitModalConfirmBody.hidden = true;
    submitModalFailedBody.hidden = false;
    modalFailedRetryBtn.focus();
  }

  function openSubmitModal() {
    const counts = S.countByStatus();
    submitModalBody.textContent = 'You have scored all ' + counts.total + ' contestants.';
    modalConfirmBtn.disabled = false;
    modalConfirmBtn.textContent = 'Submit Scores';
    modalCancelBtn.disabled = false;
    showModalConfirmBody();
    submitModalBackdrop.hidden = false;
    modalConfirmBtn.focus();
  }

  function closeSubmitModal() { submitModalBackdrop.hidden = true; }

  modalCancelBtn.addEventListener('click', closeSubmitModal);
  submitModalBackdrop.addEventListener('click', function (e) {
    if (e.target === submitModalBackdrop) closeSubmitModal();
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && !submitModalBackdrop.hidden) closeSubmitModal();
  });

  function attemptSubmit() {
    modalConfirmBtn.disabled = true;
    modalCancelBtn.disabled = true;
    modalConfirmBtn.textContent = 'Submitting…';
    setTimeout(function () {
      if (S.getState().simulateSubmitFailure) {
        showModalFailedBody();
        return;
      }
      const ok = S.submitJudging(); // re-checks completeness itself — see state.js
      if (!ok) { showModalFailedBody(); return; }
      closeSubmitModal();
      Nav.goToSubmitted();
    }, 900);
  }

  modalConfirmBtn.addEventListener('click', attemptSubmit);
  modalFailedRetryBtn.addEventListener('click', function () {
    showModalConfirmBody();
    modalConfirmBtn.disabled = false;
    modalCancelBtn.disabled = false;
    modalConfirmBtn.textContent = 'Submit Scores';
    attemptSubmit();
  });

  render();
})();
