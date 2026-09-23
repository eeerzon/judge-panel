// scoring.html?id=N[&from=review][&preview=1] — one contestant's score
// sheet. Read-only whenever isSubmitted() is true OR preview mode is on
// (preview is display-only — see PROTOTYPE-NOTES.md's Phase 5/6 notes).

(function () {
  const DATA = window.JudgePrototypeData;
  const S = window.JudgeState;
  const Nav = window.JudgeNav;

  window.JudgeChrome.init();

  const rawId = new URLSearchParams(window.location.search).get('id');
  const contestantId = Nav.guardScoringId(rawId);
  if (contestantId === null) return; // guard already redirected

  const readOnly = S.isSubmitted() || Nav.isPreviewMode();
  const scoringOrigin = Nav.getScoringOrigin();

  document.getElementById('scoring-round').textContent = DATA.round.name;

  const backBtn = document.getElementById('scoring-back');
  const positionEl = document.getElementById('scoring-position');
  const photoImg = document.getElementById('scoring-photo');
  const numberEl = document.getElementById('scoring-number');
  const nameEl = document.getElementById('scoring-name');
  const countryEl = document.getElementById('scoring-country');
  const progressEl = document.getElementById('scoring-progress');
  const totalScoreValueEl = document.getElementById('total-score-value');
  const scrollEl = document.getElementById('scoring-scroll');
  const prevBtn = document.getElementById('scoring-prev');
  const nextBtn = document.getElementById('scoring-next');
  const saveStatusEl = document.getElementById('save-status');
  const panelEl = document.querySelector('.scoring-panel');
  const bodyEl = document.querySelector('.scoring-body');

  const backLabel = scoringOrigin === 'review' ? 'Review' : 'Contestants';
  backBtn.textContent = '← ' + backLabel;
  backBtn.addEventListener('click', function () {
    if (scoringOrigin === 'review') Nav.goToReview();
    else Nav.goToContestants();
  });

  let editingKey = null;
  let editDraftValue = '';
  let fieldErrors = {};
  let noteOpen = !!S.getNote(contestantId);
  let saveTimer = null;

  function formatScore(v) { return v.toFixed(2); }

  function clampStep(raw) {
    return Math.round(raw / DATA.scoreStep) * DATA.scoreStep;
  }

  function triggerAutosave() {
    if (readOnly) return;
    saveStatusEl.textContent = 'Saving…';
    saveStatusEl.classList.add('is-saving');
    saveStatusEl.classList.remove('is-error');
    clearTimeout(saveTimer);
    saveTimer = setTimeout(function () {
      saveStatusEl.classList.remove('is-saving');
      if (S.getState().simulateSaveFailure) {
        saveStatusEl.textContent = 'Unable to save';
        saveStatusEl.classList.add('is-error');
      } else {
        saveStatusEl.textContent = 'Saved ✓';
      }
    }, 700);
  }

  function setScore(key, value) {
    if (readOnly) return;
    S.setScore(contestantId, key, value);
    delete fieldErrors[key];
    triggerAutosave();
    render();
  }

  function handleIncrement(key) {
    if (readOnly) return;
    const current = S.getContestantScores(contestantId)[key];
    const next = current === null || current === undefined ? DATA.scoreMin : clampStep(current + DATA.scoreStep);
    if (next > DATA.scoreMax) return;
    setScore(key, next);
  }

  function handleDecrement(key) {
    if (readOnly) return;
    const current = S.getContestantScores(contestantId)[key];
    if (current === null || current === undefined) return;
    const next = clampStep(current - DATA.scoreStep);
    if (next < DATA.scoreMin) return;
    setScore(key, next);
  }

  function handleQuickScore(key, value) {
    if (readOnly) return;
    setScore(key, value);
  }

  function openEdit(key) {
    if (readOnly) return;
    const current = S.getContestantScores(contestantId)[key];
    editingKey = key;
    editDraftValue = current === null || current === undefined ? '' : formatScore(current);
    delete fieldErrors[key];
    render();
    const input = scrollEl.querySelector('.score-value-input[data-key="' + key + '"]');
    if (input) { input.focus(); input.select(); }
  }

  function commitEdit(key, rawValue) {
    const raw = rawValue.trim();
    if (raw === '') { editingKey = null; setScore(key, null); return; }

    const num = Number(raw);
    if (Number.isNaN(num)) {
      editDraftValue = rawValue; fieldErrors[key] = 'Enter a number.'; render(); return;
    }
    if (num < DATA.scoreMin) {
      editDraftValue = rawValue; fieldErrors[key] = 'Minimum score is ' + DATA.scoreMin + '.'; render(); return;
    }
    if (num > DATA.scoreMax) {
      editDraftValue = rawValue; fieldErrors[key] = 'Maximum score is ' + DATA.scoreMax + '.'; render(); return;
    }
    const steps = num / DATA.scoreStep;
    if (Math.abs(Math.round(steps) - steps) > 0.001) {
      editDraftValue = rawValue; fieldErrors[key] = 'Use increments of ' + DATA.scoreStep + '.'; render(); return;
    }
    editingKey = null;
    setScore(key, clampStep(num));
  }

  function cancelEdit() { editingKey = null; render(); }

  function renderCriterion(criterion) {
    const scores = S.getContestantScores(contestantId);
    const value = scores[criterion.key] === undefined ? null : scores[criterion.key];
    const error = fieldErrors[criterion.key];
    const isEditing = !readOnly && editingKey === criterion.key;
    const canDecrement = !readOnly && value !== null && value > DATA.scoreMin;
    const canIncrement = !readOnly && (value === null || value < DATA.scoreMax);

    let labelRow = '';
    if (!criterion.standalone) {
      labelRow =
        '<div class="criterion-label-row">' +
          '<span class="criterion-label">' + criterion.label + '</span>' +
          '<span class="criterion-weight">' + criterion.weight + '%</span>' +
        '</div>';
    }

    const valueHtml = isEditing
      ? '<input type="text" inputmode="decimal" class="score-value-input' + (error ? ' has-error' : '') + '" data-key="' + criterion.key + '" value="' + editDraftValue + '" />'
      : '<span class="score-value' + (value === null ? ' is-empty' : '') +
          '"' + (readOnly ? '' : ' data-action="edit" data-key="' + criterion.key + '" tabindex="0" role="button" aria-label="Edit ' + criterion.label + ' score, current value ' + (value === null ? 'not set' : formatScore(value)) + '"') +
        '>' + (value === null ? '—' : formatScore(value)) + '</span>';

    let quickScoreHtml = '';
    if (criterion.quickScore) {
      quickScoreHtml =
        '<div class="quick-score-row">' +
          '<span class="quick-score-label">Quick score</span>' +
          criterion.quickScore.map(function (v) {
            const selected = value === v ? ' is-selected' : '';
            return '<button type="button" class="quick-score-btn' + selected + '" data-action="quick" data-key="' + criterion.key + '" data-value="' + v + '"' + (readOnly ? ' disabled' : '') + '>' + v + '</button>';
          }).join('') +
        '</div>';
    }

    return (
      '<div class="criterion-block">' +
        labelRow +
        '<div class="score-control">' +
          '<button type="button" class="score-btn score-btn-minus" data-action="decrement" data-key="' + criterion.key + '" aria-label="Decrease ' + criterion.label + ' score"' + (canDecrement ? '' : ' disabled') + '>−</button>' +
          valueHtml +
          '<button type="button" class="score-btn score-btn-plus" data-action="increment" data-key="' + criterion.key + '" aria-label="Increase ' + criterion.label + ' score"' + (canIncrement ? '' : ' disabled') + '>+</button>' +
        '</div>' +
        (error ? '<p class="score-error" role="alert">' + error + '</p>' : '') +
        quickScoreHtml +
      '</div>'
    );
  }

  function renderSection(section) {
    return (
      '<div class="scoring-section">' +
        '<div class="scoring-section-heading">' +
          '<span>' + section.heading + '</span>' +
          '<span class="scoring-section-weight">' + section.weight + '%</span>' +
        '</div>' +
        section.criteria.map(renderCriterion).join('') +
      '</div>'
    );
  }

  function renderNoteBlock() {
    const note = S.getNote(contestantId);
    if (readOnly) {
      if (!note) return '';
      return (
        '<div class="note-block">' +
          '<label class="note-label">Note</label>' +
          '<textarea class="note-textarea" readonly>' + note + '</textarea>' +
        '</div>'
      );
    }
    if (!noteOpen) {
      return '<button type="button" class="add-note-btn" data-action="open-note">+ Add note</button>';
    }
    return (
      '<div class="note-block">' +
        '<label class="note-label" for="contestant-note">Note (optional)</label>' +
        '<textarea id="contestant-note" class="note-textarea" placeholder="Optional note about this contestant…">' + note + '</textarea>' +
      '</div>'
    );
  }

  function render() {
    const contestant = S.getContestant(contestantId);
    const numberLabel = '#' + String(contestant.number).padStart(2, '0');

    positionEl.textContent = String(contestant.number).padStart(2, '0') + ' / ' + DATA.contestants.length;
    photoImg.src = contestant.photo;
    numberEl.textContent = numberLabel;
    nameEl.textContent = contestant.name;
    countryEl.textContent = contestant.country;

    const info = S.getContestantStatus(contestantId);
    if (readOnly && S.isSubmitted()) {
      progressEl.textContent = 'Submitted';
      progressEl.classList.add('is-complete');
    } else {
      const isComplete = info.status === 'scored';
      progressEl.textContent = isComplete ? '✓ Complete' : info.scoredCount + ' of ' + info.total + ' criteria scored';
      progressEl.classList.toggle('is-complete', isComplete);
    }

    const total = S.calculateContestantTotal(contestantId);
    totalScoreValueEl.textContent = total === null ? '—' : total.toFixed(2);
    totalScoreValueEl.classList.toggle('is-empty', total === null);

    const lockBannerHtml = (readOnly && S.isSubmitted())
      ? '<div class="scoring-lock-banner"><span class="scoring-lock-badge">Submitted</span>' +
        '<span>Your scores have been submitted and can no longer be edited.</span></div>'
      : '';
    scrollEl.innerHTML = lockBannerHtml + DATA.scoringSections.map(renderSection).join('') + renderNoteBlock();

    prevBtn.disabled = contestant.number === 1;
    const isLast = contestant.number === DATA.contestants.length;
    nextBtn.disabled = false;
    if (readOnly) {
      nextBtn.textContent = isLast ? ('Back to ' + backLabel + ' →') : 'Next →';
    } else {
      nextBtn.textContent = isLast ? ('Save & Back to ' + backLabel + ' →') : 'Save & Next →';
    }

    const input = scrollEl.querySelector('.score-value-input');
    if (input) {
      input.addEventListener('blur', function () {
        const key = input.dataset.key;
        const rawValue = input.value;
        setTimeout(function () {
          if (editingKey === key) commitEdit(key, rawValue);
        }, 0);
      });
      input.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') { e.preventDefault(); input.blur(); }
        else if (e.key === 'Escape') { e.preventDefault(); cancelEdit(); }
      });
      if (editingKey && fieldErrors[editingKey]) {
        input.focus();
        const len = input.value.length;
        input.setSelectionRange(len, len);
      }
    }

    const noteTextarea = document.getElementById('contestant-note');
    if (noteTextarea) {
      noteTextarea.addEventListener('input', function () {
        S.setNote(contestantId, noteTextarea.value);
      });
      noteTextarea.addEventListener('blur', function () { triggerAutosave(); });
    }
  }

  scrollEl.addEventListener('click', function (e) {
    if (readOnly) return;
    const target = e.target.closest('[data-action]');
    if (!target) return;
    const action = target.dataset.action;
    const key = target.dataset.key;
    if (action === 'increment') handleIncrement(key);
    else if (action === 'decrement') handleDecrement(key);
    else if (action === 'edit') openEdit(key);
    else if (action === 'quick') handleQuickScore(key, Number(target.dataset.value));
    else if (action === 'open-note') {
      noteOpen = true;
      render();
      const ta = document.getElementById('contestant-note');
      if (ta) ta.focus();
    }
  });

  scrollEl.addEventListener('keydown', function (e) {
    const target = e.target.closest('[data-action="edit"]');
    if (target && (e.key === 'Enter' || e.key === ' ')) {
      e.preventDefault();
      openEdit(target.dataset.key);
    }
  });

  function validateBeforeLeaving() {
    if (editingKey) {
      const input = scrollEl.querySelector('.score-value-input[data-key="' + editingKey + '"]');
      if (input) commitEdit(editingKey, input.value);
    }
    return !(editingKey && fieldErrors[editingKey]);
  }

  prevBtn.addEventListener('click', function () {
    if (!validateBeforeLeaving()) return;
    const contestant = S.getContestant(contestantId);
    if (contestant.number > 1) Nav.goToScoring(DATA.contestants[contestant.number - 2].id, scoringOrigin);
  });

  nextBtn.addEventListener('click', function () {
    if (!validateBeforeLeaving()) return;
    if (!readOnly) triggerAutosave();
    const contestant = S.getContestant(contestantId);
    if (contestant.number < DATA.contestants.length) {
      Nav.goToScoring(DATA.contestants[contestant.number].id, scoringOrigin);
    } else if (scoringOrigin === 'review') {
      Nav.goToReview();
    } else {
      Nav.goToContestants();
    }
  });

  saveStatusEl.textContent = readOnly && S.isSubmitted() ? 'Locked' : 'Saved ✓';
  render();
  panelEl.scrollTop = 0;
  bodyEl.scrollTop = 0;
  scrollEl.scrollTop = 0;
})();
