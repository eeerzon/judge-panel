// King & Queen of the Pacific — Judge Panel Prototype
// Shared navigation helpers + page guards. Every page (pages/*.html) links
// to another page through these functions instead of a hardcoded relative
// URL, and calls the matching guard() function before rendering anything
// state-dependent, so the "can this page be reached right now" rule lives
// in exactly one place per page.

(function () {
  const S = window.JudgeState;

  function qs(name) {
    return new URLSearchParams(window.location.search).get(name);
  }

  // Dev-only escape hatch so every page/state combination can be opened
  // directly for visual review, without needing to walk the normal flow
  // first or fake up business state. See PROTOTYPE-NOTES.md — preview mode
  // never writes to localStorage and never flips isSubmitted for real.
  function isPreviewMode() {
    return qs('preview') === '1';
  }

  function goToStandby() { window.location.href = 'standby.html'; }
  function goToContestants() { window.location.href = 'contestants.html'; }
  // `from` ('gallery' | 'review') travels in the URL, not shared JS memory
  // (there is none across a real page navigation) — scoring.js reads it
  // back via getScoringOrigin() so Back/last-contestant-Next return to
  // wherever the judge actually came from instead of always Contestants.
  function goToScoring(id, from) {
    const originParam = from ? '&from=' + encodeURIComponent(from) : '';
    window.location.href = 'scoring.html?id=' + encodeURIComponent(id) + originParam;
  }
  function goToReview() { window.location.href = 'review.html'; }
  function goToSubmitted() { window.location.href = 'submitted.html'; }

  function getScoringOrigin() {
    return qs('from') === 'review' ? 'review' : 'gallery';
  }

  // ---- Page guards — each returns true if the page should render normally.
  // A guard that redirects returns false so the calling page can bail out
  // (stop its own init) instead of rendering half-built state first.

  // scoring.html?id=X — id must name a real contestant, preview mode aside.
  function guardScoringId(rawId) {
    if (isPreviewMode()) {
      // In preview, fall back to contestant #1 for a blank/invalid id so
      // the page still has something real to render.
      const id = Number(rawId);
      return S.getContestant(id) ? id : window.JudgePrototypeData.contestants[0].id;
    }
    const id = Number(rawId);
    if (!rawId || Number.isNaN(id) || !S.getContestant(id)) {
      goToContestants();
      return null;
    }
    return id;
  }

  // submitted.html — only reachable normally once isSubmitted is true.
  // Preview mode bypasses this to render a mocked "as if submitted" view
  // without ever touching real stored state.
  function guardSubmitted() {
    if (isPreviewMode()) return true;
    if (!S.isSubmitted()) {
      goToReview();
      return false;
    }
    return true;
  }

  window.JudgeNav = {
    isPreviewMode: isPreviewMode,
    goToStandby: goToStandby,
    goToContestants: goToContestants,
    goToScoring: goToScoring,
    goToReview: goToReview,
    goToSubmitted: goToSubmitted,
    getScoringOrigin: getScoringOrigin,
    guardScoringId: guardScoringId,
    guardSubmitted: guardSubmitted,
  };
})();
