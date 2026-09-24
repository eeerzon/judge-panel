// contestants.html — the 15-contestant photo grid. Reachable any time
// (before or after submission — see section 12 of the refactor brief): once
// submitted it shows the "Judging Submitted" banner, every card reads
// Scored, and the header CTA becomes "View Submission" instead of
// "Review & Submit". No guard redirects away from this page in any state.

(function () {
  const DATA = window.JudgePrototypeData;
  const S = window.JudgeState;
  const Nav = window.JudgeNav;

  window.JudgeChrome.init();
  const round = Nav.guardAssignedRound();
  if (!round) return;
  const contestants = DATA.getRoundContestants(round.id);

  document.getElementById('gallery-event-name').textContent = DATA.event.name;
  document.getElementById('gallery-round').textContent = round.name;
  document.getElementById('gallery-judge-identity').textContent =
    'Judge ' + String(DATA.judge.number).padStart(2, '0') + ' · ' + DATA.judge.name;

  const grid = document.getElementById('contestant-grid');
  const filterPills = document.querySelectorAll('.filter-pill');
  const countAllEl = document.getElementById('count-all');
  const countToScoreEl = document.getElementById('count-to-score');
  const countScoredEl = document.getElementById('count-scored');
  const progressCountEl = document.getElementById('progress-count');
  const progressBarFillEl = document.getElementById('progress-bar-fill');
  const reviewCtaBtn = document.getElementById('review-cta-btn');
  const gallerySubmittedBanner = document.getElementById('gallery-submitted-banner');
  const standbyActionBtn = document.getElementById('standby-action');

  let currentFilter = 'all';

  function statusMeta(status, draftInfo) {
    if (status === 'scored') return { className: 'status-scored', label: '✓ Scored' };
    if (status === 'draft') return { className: 'status-draft', label: 'Draft · ' + draftInfo.scoredCount + ' / ' + draftInfo.total + ' criteria' };
    return { className: 'status-not-started', label: 'Not Scored' };
  }

  function initials(name) {
    return name
      .split(' ')
      .filter(function (part) { return part && DATA.nameTitles.indexOf(part.toLowerCase()) === -1; })
      .slice(0, 2)
      .map(function (part) { return part[0]; })
      .join('')
      .toUpperCase();
  }

  function buildCard(contestant) {
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'contestant-card';
    card.setAttribute('role', 'listitem');

    const info = S.getContestantStatus(contestant.id);
    const status = statusMeta(info.status, info);
    card.dataset.status = info.status;

    const numberLabel = '#' + String(contestant.number).padStart(2, '0');
    const hue = DATA.photoHues[(contestant.number - 1) % DATA.photoHues.length];
    const fallbackBg = 'linear-gradient(160deg, hsl(' + hue + ', 32%, 22%), hsl(' + hue + ', 28%, 12%))';

    card.setAttribute('aria-label', numberLabel + ' ' + contestant.name + ', ' + contestant.country + ', ' + status.label);

    card.innerHTML =
      '<div class="contestant-photo" style="background: ' + fallbackBg + ';">' +
        '<img src="' + contestant.photo + '" alt="" loading="lazy" ' +
          'onerror="this.style.display=\'none\'; this.nextElementSibling.style.display=\'flex\';" />' +
        '<span class="contestant-photo-fallback" style="display:none;">' + initials(contestant.name) + '</span>' +
      '</div>' +
      '<div class="contestant-body">' +
        '<span class="contestant-number">' + numberLabel + '</span>' +
        '<span class="contestant-name">' + contestant.name + '</span>' +
        '<span class="contestant-country">' + contestant.country + '</span>' +
        '<span class="contestant-status ' + status.className + '">' +
          '<span class="status-dot" aria-hidden="true"></span>' + status.label +
        '</span>' +
      '</div>';

    card.addEventListener('click', function () {
      Nav.goToScoring(contestant.id);
    });

    return card;
  }

  function matchesFilter(contestant, filter) {
    const status = S.getContestantStatus(contestant.id).status;
    if (filter === 'all') return true;
    if (filter === 'scored') return status === 'scored';
    if (filter === 'to-score') return status === 'not-started' || status === 'draft';
    return true;
  }

  function renderGrid() {
    grid.innerHTML = '';
    const visible = contestants.filter(function (c) { return matchesFilter(c, currentFilter); });

    if (visible.length === 0) {
      const empty = document.createElement('p');
      empty.className = 'empty-state';
      empty.textContent = 'No contestants in this filter.';
      grid.appendChild(empty);
      return;
    }

    visible.forEach(function (c) { grid.appendChild(buildCard(c)); });
  }

  function updateHeader() {
    const counts = S.countByStatus();
    countAllEl.textContent = counts.total;
    countToScoreEl.textContent = counts.total - counts.scored;
    countScoredEl.textContent = counts.scored;

    progressCountEl.textContent = counts.scored + ' / ' + counts.total;
    progressBarFillEl.style.width = Math.round((counts.scored / counts.total) * 100) + '%';

    gallerySubmittedBanner.hidden = !S.isSubmitted();
    if (S.isSubmitted()) {
      reviewCtaBtn.textContent = 'View Submission';
    } else if (counts.scored === counts.total) {
      reviewCtaBtn.textContent = 'Review & Submit';
    } else {
      reviewCtaBtn.textContent = 'Review Progress';
    }
  }

  filterPills.forEach(function (pill) {
    pill.addEventListener('click', function () {
      currentFilter = pill.dataset.filter;
      filterPills.forEach(function (p) {
        const isActive = p === pill;
        p.classList.toggle('is-active', isActive);
        p.setAttribute('aria-selected', String(isActive));
      });
      renderGrid();
    });
  });

  reviewCtaBtn.addEventListener('click', function () { Nav.goToReview(round.id); });
  standbyActionBtn.addEventListener('click', function () { Nav.goToStandby(round.id); });

  updateHeader();
  renderGrid();
})();
