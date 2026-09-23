# Judge Panel Prototype — Handoff

**Client:** King & Queen of the Pacific 2026 (pageant, Preliminary round)
**What this is:** a click-through interaction/visual prototype for a tablet-based judge scoring app — **multi-page HTML, double-click portable**. No backend, no build step, no server requirement — open `index.html` (a dev-only launcher) or any `pages/*.html` file directly from Finder/Explorer, in Chrome or Safari.
**What this is not:** the production app. It exists to validate flow, layout, and interaction decisions before the real (likely Flutter) app is built. See `PROTOTYPE-NOTES.md` for the specific gaps that must NOT be carried into production.

## Opening this prototype

**Just double-click any HTML file.** Every page — `index.html`, `pages/standby.html`, `pages/contestants.html`, `pages/scoring.html`, `pages/review.html`, `pages/submitted.html` — works directly via `file://`, with correct styling, working navigation, and working Preview Mode. No server, no build step, no install.

An earlier version of this prototype briefly required a local server due to a `file://` compatibility issue; that requirement (and the warning banner that came with it) has been removed — see "Direct-file (`file://`) compatibility" below for what changed and how it was verified.

`start-server.command` (double-click to serve on `http://localhost:8934`) is still included as an **optional convenience** if you want to test the full persistent flow over HTTP instead — it is not required for anything.

## Status: Phase 1–6 done. Prototype is UX-reference/frozen — stop here until told otherwise

```
standby.html → contestants.html → scoring.html?id=N → review.html → submitted.html (locked)
```

Phases 1–5 built the interaction/visual design as a **single-page** app (`_legacy-single-page/index.html` + `app.js` + `styles.css`, kept as a reference copy — no longer live). Phase 6 refactored that same frozen UX into **5 separate HTML pages** sharing state through `localStorage` instead of one page's JS memory, added page guards (a judge can't reach `submitted.html` before actually submitting, can't open `scoring.html?id=999`), and added a `?preview=1` mode so every page/state combination can be opened directly for visual review without walking the normal flow. See "Phase 6 — multi-page refactor" below for the file map and architecture, and `PROTOTYPE-NOTES.md` for exactly what's real vs. simulated at every layer.

Explicitly **not built**, per repeated instruction across sessions: Result/Ranking engine, Head Judge UI, other-judges' scores, admin dashboard, backend/API, login, real submission, and no Flutter code. Do not start any of that without the user asking again.

## Phase 6 — multi-page refactor: file map

```
judge-prototype/
  index.html               dev-only prototype launcher (NOT the judge-facing entry point)
  start-server.command     OPTIONAL — double-click to serve over http://localhost:8934
                            instead of file://, if you want the full-HTTP test path
  _legacy-single-page/      frozen reference copy of the pre-Phase-6 single-page prototype
    index.html, app.js, styles.css

  pages/
    standby.html            idle/lock screen — tap anywhere goes to contestants.html
    contestants.html        15-contestant photo grid + filters (no guard — open anytime)
    scoring.html             ?id=N required — one contestant's score sheet
    review.html              compact list + completion summary + Submit modal (no guard)
    submitted.html            post-submit confirmation — GUARDED (see below)

  assets/
    css/
      tokens.css             :root theme variables only
      components.css         everything reusable + per-screen shell layout (the pre-Phase-6
                              stylesheet, effectively verbatim — see its own header comment
                              for why it wasn't hand-split further)
      pages.css              Phase 6-only additions: preview banner, launcher styles
    js/
      mock-data.js            window.JudgePrototypeData — event/judge/round/contestants/
                              scoring rubric. Static reference data, never mutated.
      state.js                window.JudgeState — the ONLY module that reads/writes
                              localStorage (key: kreenJudgePrototype). Owns every
                              business-logic helper: getContestantStatus, 
                              calculateContestantTotal, isContestantComplete,
                              areAllContestantsComplete, isSubmitted, submitJudging, ...
      navigation.js           window.JudgeNav — goToStandby/Contestants/Scoring/Review/
                              Submitted, isPreviewMode(), guardScoringId(), guardSubmitted()
      chrome.js               window.JudgeChrome — shared preview banner / offline banner /
                              connection-status / dev panel / standby-timeout wiring, so
                              this isn't duplicated 5 times across the page scripts
      standby.js, contestants.js, scoring.js, review.js, submitted.js
                              one script per page, wires that page's DOM to State+Nav
    images/                  15 contestant banner photos (Miss/Mister N.jpg) + KQP logo
                              (moved here from assets/ directly — paths are now
                              ../assets/images/... relative to pages/*.html)

_docs/
  PROTOTYPE-NOTES.md   persistence/submission/Phase-5-simulation/Phase-6-guard caveats —
                       read before assuming any state is "real"
  HANDOFF.md           this file
```

No git repo here yet — there's no version history to check before editing; treat the files on disk as the only source of truth. (The `_legacy-single-page/` copy exists specifically as a manual "before" snapshot since there's no git to diff against.)

## Normal navigation flow

```
pages/standby.html
  → tap anywhere → pages/contestants.html
      → tap a card → pages/scoring.html?id=N&from=gallery
          → Save & Next → next id, same &from
          → Back / last-contestant exit → back to contestants.html
      → "Review & Submit" → pages/review.html
          → open a row → pages/scoring.html?id=N&from=review
              → Back / last-contestant exit → back to review.html (not contestants.html)
          → "Submit Judging" (only enabled at 15/15) → confirm modal → pages/submitted.html
  submitted.html "Return to Standby" → standby.html
  submitted.html "View Submitted Scores" → review.html (now fully locked/read-only)
```

`from=gallery|review` in the URL replaces the old single-page `scoringEntryOrigin` JS variable — there's no shared memory across a real page navigation, so this has to travel in the URL instead.

## Page guards

| Page | Guard | Bypass |
|---|---|---|
| `scoring.html?id=N` | `N` must be a real contestant id, else redirect to `contestants.html` | `?preview=1` falls back to contestant #1 instead of redirecting |
| `submitted.html` | Must have `isSubmitted === true` in storage, else redirect to `review.html` | `?preview=1` renders a mocked "15 scored, submitted at 21:42" view, never reads or writes real state |
| `contestants.html`, `review.html` | **No guard** — reachable at any completion level, by design (Review's whole job is showing what's incomplete) | n/a |
| Submission itself | `JudgeState.submitJudging()` re-checks `areAllContestantsComplete()` server-side-style (i.e. in the one shared module, not just in the button's disabled state) before setting `isSubmitted = true` | none — always enforced, even if a page's UI is somehow bypassed |

## Preview mode (`?preview=1`)

For visual review without walking the normal flow — see the launcher (`index.html`) for ready-made links. Shows a small "PROTOTYPE PREVIEW" strip at the top of the page. Never writes to `localStorage`, never sets `isSubmitted`. Disables the standby-inactivity timeout (so a reviewer isn't bounced to Standby mid-review) and renders `scoring.html` read-only regardless of submission state (preview is display-only, not an editing sandbox).

## Key architectural patterns (read before editing `assets/js/*.js`)

- **Single source of truth, now in one file instead of one closure.** Every score/status/total formula lives in `assets/js/state.js` and nowhere else — `scoring.js` and `review.js` both call `S.calculateContestantTotal(id)` rather than each computing it. If a new page needs a business fact, add a function to `state.js`, don't inline the logic.
- **Full re-render on every mutation**, same as the single-page prototype — each page's own `.js` file rebuilds its dynamic containers' `innerHTML` from scratch (`render()` in `scoring.js`, `renderList()` in `review.js`, etc.) rather than diffing. Click handlers are delegated on a stable parent element for the same reason children get thrown away constantly.
- **`localStorage` is the only thing that survives a page navigation.** There is no `window.something` global carrying state between `contestants.html` and `scoring.html` — they're different documents. Anything that needs to survive a navigation (which contestant is selected, `from=gallery|review`, every score) goes through `state.js` or the URL, never a JS variable.
- **Read-only lock is one boolean, checked per-page now instead of per-function.** `scoring.js` computes `const readOnly = S.isSubmitted() || Nav.isPreviewMode();` once at the top and threads it through; every mutation path (`handleIncrement`, `handleDecrement`, `handleQuickScore`, `openEdit`, the note textarea, the delegated click handler) checks it. If you add a new way to change a score, it needs this guard too.
- **Chrome (dev panel, offline banner, preview banner, connection status) is one shared module (`chrome.js`)**, called via `window.JudgeChrome.init()` at the top of every page script, specifically so this ~140 lines isn't hand-copied into 5 files and drift out of sync.

## What's genuinely fake here (don't be surprised) — see PROTOTYPE-NOTES.md for the full list

- `localStorage`, not a real backend — see PROTOTYPE-NOTES.md's "localStorage is a prototype convenience" section before recommending anything from `state.js` for production.
- "Submitting…" is a `setTimeout(…, 900)`, not a request.
- Connection status, save-failure, and submit-failure states are all dev-panel-driven booleans with no real device/network condition behind them.
- The standby inactivity timeout (45s) is intentionally short for demo/testing, not a validated production duration.
- 5 demo contestants (#1, #2, #3, #6, #8) start with partial/full scores in the default seed so filters have something to show; `mock-data.js` → `demoScores`.

## Test results from this session (all passed)

- **Refresh persistence:** score entered → full browser reload → value still there (localStorage roundtrip confirmed via `getBoundingClientRect`/DOM read, not just visual glance).
- **Cross-page persistence:** score entered on `scoring.html?id=3` → navigate to `contestants.html` and back → same value.
- **Guard: invalid scoring id** — `scoring.html?id=999` redirects to `contestants.html`.
- **Guard: submitted before submit** — `submitted.html` (no `preview`) before any submission redirects to `review.html`.
- **Preview mode does not leak into real state** — opened `submitted.html?preview=1` with a real 4/15 state, confirmed via `localStorage.getItem(...)` that `isSubmitted` was still `false` afterward.
- **Full submit flow** — seeded all 15 complete, Review → "Submit Judging" → modal → "Submit Scores" → real (non-preview) `submitted.html` with a real timestamp.
- **Post-submit lock, verified on all three pages:**
  - `scoring.html?id=1` — green "Submitted" lock banner, stepper buttons `disabled` (confirmed via `.disabled` property after a click attempt did nothing), footer says "Locked", button reads "Next →" not "Save & Next →".
  - `contestants.html` — "Judging Submitted" banner, header CTA "View Submission", every card "✓ Scored".
  - `review.html` — "Judging submitted. These scores are locked..." note, footer "Judging submitted — scores are locked.", zero Continue/Score buttons anywhere.
- **Reset Prototype State** (launcher) — cleared `localStorage` and restored the exact original demo seed (3/15 scored, #3 back to Draft 3/5) — confirmed by re-visiting `contestants.html` after reset.
- **Responsive** — 1280×800, 1440×900, 800×1280 all checked post-refactor on Contestants/Scoring/Review; no overflow, no regression versus the frozen single-page screenshots.
- Zero console errors across every navigation and every guard/preview/failure-simulation path exercised above.

## Bugs found and fixed during the Phase 6 refactor

- The refactor's guard/state/navigation logic itself was a faithful port of the already-frozen Phase 1–5 logic — no new logic bugs. (Separately, earlier in this same handoff's history, two `[hidden]`-vs-`display` CSS specificity bugs were found and fixed on `.offline-banner` and `.submitted-banner`; both are already reflected in `components.css`.)
- **Reported once as "opening `scoring.html` by double-click shows an unstyled page":** the first response to this added a `file://`-detecting warning banner that blocked every page with a "needs a local server" message. That response was **wrong** — a full code audit (below) found nothing in this codebase (no ES modules, no `fetch`, no absolute `/…` paths) that actually requires a server, so the warning was removed entirely rather than kept as a safety net. The original unstyled render could not be reproduced against this codebase's actual `<script src>`/`<link>` structure; if it recurs, capture the browser console output (a real resource-loading failure would show a `net::ERR_FAILED` or "Not allowed to load local resource" there) before assuming a server is needed again.

## Direct-file (`file://`) compatibility audit

Performed after the local-server requirement was removed, to confirm the codebase has nothing that would actually need one:

- **No ES modules** — `grep`'d every `pages/*.html`, `index.html`, and `assets/js/*.js` for `type="module"`, `import `, `export ` → zero matches. Every script is a classic script (`<script src="...">`, IIFE-wrapped), loaded in a fixed order (`mock-data.js` → `state.js` → `navigation.js` → `chrome.js` → the page's own script) that every page follows identically.
- **No `fetch`/`XMLHttpRequest`** — zero matches for either across all JS. All data (`window.JudgePrototypeData` in `mock-data.js`) is inline JS, not loaded over HTTP.
- **No absolute root paths** — zero matches for `href="/` or `src="/` anywhere. Every stylesheet, script, and image path is relative (`../assets/css/...`, `../assets/js/...`, `../assets/images/...` from `pages/*.html`; `assets/css/...`, `assets/js/...` from the root `index.html`), which resolves identically under `file://` and `http://`.
- **Navigation is relative-filename-based** — `navigation.js`'s `goToStandby()`/`goToContestants()`/`goToScoring(id, from)`/`goToReview()`/`goToSubmitted()` all assign `window.location.href` to a bare filename (`'standby.html'`, `'scoring.html?id=' + id + ...`), never a full URL — confirmed by grep, no `http://` or `localhost` baked into any navigation call.
- **`localStorage` access is already defensively wrapped** — `state.js`'s `load()`/`persist()` both wrap every `localStorage` call in `try/catch` and fall back to `defaultState()` (in-memory for that pageview) on any error. If a browser/security-mode combination throws on `localStorage` under `file://` (some strict Safari private-browsing configurations do), the prototype degrades to non-persistent rather than crashing — it was already written this way before this task, not added for this fix.

None of this required a code change beyond removing the warning banner and its supporting copy — the underlying page structure was already `file://`-safe.

## Open UX decision flagged, not yet resolved (carried over from Phase 4/5)

`renderFooter()` in `review.js` currently *hides* the Submit button entirely while incomplete and shows "Complete Remaining Scores" instead, rather than showing a permanently-visible, grayed-out "Submit Judging" with a reason underneath (the original brief described both patterns as acceptable). If the user picks the other pattern, it's a one-function change.

## Karpathy principles this prototype tries to hold to

- **Legible over clever.** Every page is a full re-render from a plain object graph read out of `localStorage` — no virtual DOM, no reactive framework, no build step, no bundler. Anyone can open any one `assets/js/*.js` file and read top-to-bottom what happens when a button is clicked, without needing the other four page scripts open at the same time.
- **Delete the scaffolding you don't need yet.** No client-side router for 5 pages (real `<a href>`/`location.href` navigation is enough), no state management library for a handful of localStorage-backed fields, no component framework for markup that's just template strings. Multi-page + localStorage is already more infrastructure than Phase 1–5's single file — resist adding a build step or a framework on top of it before something visibly strains.
- **A prototype's job is to be wrong quickly, not right permanently.** `localStorage`, the fake submit delay, and the dev-panel-only failure states are not oversights — they're the fastest way to test the *flow* (including "can a judge reach a page they shouldn't") without paying the cost of a real backend before anyone has confirmed the flow is right. `PROTOTYPE-NOTES.md` exists specifically so these distinctions survive the handoff to whoever builds production.
- **Bugs found by testing, not by inspection.** Every guard, every preview-mode path, and the full submit-then-verify-lock flow above were exercised in a live browser with real navigations and real `localStorage` reads — not reasoned about from reading the code. Keep verifying that way; a page guard that "looks right" in the source is not the same as one confirmed to redirect.
