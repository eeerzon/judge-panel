# Judge Panel Prototype — Notes

## ⚠️ Superseded by Phase 6 (multi-page + localStorage) — read this first

Phases 1–5 (below) describe the **original single-page prototype**
(`judge-prototype/app.js`, one `index.html`), which held all state in a
single in-memory `CONTESTANTS` array with no `localStorage` at all. That
file still exists as a reference copy at
`judge-prototype/_legacy-single-page/` but is **no longer the live
prototype**.

Phase 6 refactored the same frozen UX into **multi-page HTML**
(`pages/standby.html`, `contestants.html`, `scoring.html`, `review.html`,
`submitted.html`) sharing state through **`localStorage`**
(`assets/js/state.js`, key `kreenJudgePrototype`) instead of one page's JS
memory — see that phase's handoff report for the full rationale, file map,
and test results. The persistence/submission-state caveats below (Phase
3/4/5) still apply in spirit, just read `localStorage` wherever they say
"in-memory `CONTESTANTS` array" or "plain variable in `app.js`".

## localStorage is a prototype convenience, not a production recommendation

Phase 6 added real `localStorage` persistence so the multi-page prototype
survives a refresh and a page-to-page navigation — this is deliberately
**more** representative of production than Phases 1–5's memory-only state
was, but it is still only a prototyping convenience:

- `localStorage` has no encryption, no device pairing, no auth, no size
  guarantees, and can be cleared by the OS, the browser, or the user at any
  time with zero warning.
- It is single-device, single-browser-profile only — nothing here syncs
  across tablets, and nothing here is a substitute for a real backend.
- Production (Flutter) needs a **local database** (SQLite/Hive or
  equivalent) for on-device durability, an **API** for the actual judging
  backend, **server-side state** as the source of truth for submission, and
  a **real sync engine** for offline/online reconciliation — not
  `localStorage` ported as-is. Treat every `JudgeState` function in
  `assets/js/state.js` as a sketch of the *shape* of that logic
  (`getContestantStatus`, `calculateContestantTotal`,
  `areAllContestantsComplete`, `submitJudging`, …), not as code to lift
  into the Flutter app.

## Persistence (Phase 3, historical — see Phase 6 note above)

The original prototype (`judge-prototype/_legacy-single-page/app.js`) held
all contestant scores and notes in a single in-memory `CONTESTANTS` array.
There was no backend, no `localStorage`, no sync of any kind.

- A browser reload reset every score back to the hardcoded `DEMO_SCORES`
  seed — this was expected and acceptable for a prototype whose job is to
  validate interaction design, not to hold real judging data.
- This is **not** acceptable for the production app. A real judging session
  runs for hours on a tablet that can lose power, lose Wi-Fi, or get
  accidentally backgrounded/reloaded — losing a judge's scores mid-round is
  a serious failure, not a cosmetic one.

**What production (Flutter) needs instead:**
- Local persistent storage on-device (e.g. SQLite/Hive/shared-prefs-backed
  store) so an app kill, reload, or offline stretch never loses a score
  already entered.
- Sync to the backend when connectivity is available, with a clear
  local-draft vs. submitted-to-server distinction (mirrors the
  draft/submitted/locked score-sheet lifecycle already planned in the
  `juri` Judging System backend redesign — see that project's docs before
  designing this from scratch).
- Conflict handling for the case where the same judge's session resumes on
  a different device or after a long offline gap.

This note exists so the persistence gap doesn't get silently carried into
production as "that's just how it already worked in the prototype."

## Submission state (Phase 4)

Phase 4 adds two more in-memory-only values: `isSubmitted` (boolean) and
`submittedAt` (a `Date`, set once at confirm time). Both live as plain
variables in `app.js`, exactly like every score — a reload resets a
"submitted" session back to not-submitted, same as it resets scores back to
the `DEMO_SCORES` seed.

- This is fine for the prototype: the point is to test the review → confirm
  → lock → read-only flow, not to prove it survives a crash.
- It is **not** fine for production. "Judging Submitted" is the one state in
  this whole app that has to be irreversible from the judge's side — if a
  submitted session can be un-submitted just by reloading the tablet, the
  lock isn't real, and a judge (or anyone else with access to the tablet)
  could reopen and change scores after the official cutoff.
- Production (Flutter) needs the submission to be committed to backend
  state as soon as the judge confirms, not just flagged locally — the
  "locked" UI should reflect a server-confirmed submission, with local
  storage used only to survive being offline at the moment of submit (queue
  and retry), never as the source of truth for whether submission happened.
- The Head Judge "reopen" capability that earlier drafts of the confirmation
  modal copy mentioned has been removed from the copy itself (Phase 5
  simplified it to plain lock language for a non-technical judge) but the
  underlying gap is unchanged: this is a backend/authorization concern the
  prototype does not model — there is no way to un-submit here once
  `isSubmitted` is true except a full page reload.

## Phase 5 additions — all simulated, none of this is real (read before demoing)

Phase 5 added several states a real tablet app must eventually support, but
every one of them is faked for review purposes only, driven by the
"Prototype Controls" panel (bottom-collapsed strip, expands on tap) that is
**not part of the judge-facing product** and must not ship:

- **Connection status** (`Online` / `Offline` / `Syncing…` / `Synced`,
  shown in the Standby footer and Gallery header) is a plain variable
  (`connectionState`) toggled only by the dev panel. There is no real
  network check — `navigator.onLine`, a heartbeat ping, or anything else
  that reflects the device's actual state. Production must wire this to
  real connectivity.
- **The offline banner** ("No connection — your scores are safe on this
  device…") only appears because `connectionState === 'offline'` was set
  by hand. It correctly never blocks interaction (no modal, judging stays
  usable) but it also never reflects reality until Flutter wires up an
  actual connectivity listener.
- **"Unable to save"** (dev panel → Save failure: On) and **"Submission
  failed"** (dev panel → Submit failure: On) are both `if (simulateFlag)`
  branches with no real failure condition behind them — no dropped
  request, no storage-write error, nothing. They exist purely so the
  *visual design* of a failure state can be reviewed before Flutter has to
  invent one under real error-handling pressure. Neither includes retry
  backoff, offline queueing, or conflict resolution — production needs all
  three.
- **The standby inactivity timeout** (default 45s, intentionally short for
  demo/testing — see `STANDBY_TIMEOUT_MS` in `app.js`) is real in the sense
  that it actually fires via `setTimeout`, but the duration, the exact
  reset events (`pointerdown`/`keydown`/`wheel` only — no `touchmove`), and
  the "don't fire while the submit modal is open" guard are all
  placeholder judgment calls for a prototype, not a validated production
  spec. It never clears `isSubmitted`, scores, or notes — only which
  screen is visible — which is the one behavior production must preserve
  exactly.
- Phase 5 (single-page): none of these states persisted across a reload —
  connection state, both failure toggles, and the timeout all reset to
  their defaults (`synced`, off, off, 45s) on refresh, same as scores did.
  **Phase 6 update:** now that state lives in `localStorage`, connection
  state and the two failure toggles *do* persist across reload/navigation
  (they're part of the same `kreenJudgePrototype` blob) — if a dev panel
  toggle is left "On" and forgotten, it stays on until manually turned off
  or "Reset Prototype State" is used from the launcher (`index.html`). The
  standby timeout itself still resets on every reload (it's a `setTimeout`,
  not stored state) and is disabled entirely in `?preview=1`.

**What production (Flutter) needs instead of every item above:** real
connectivity detection, a real local-first write path with a real failure
mode (not a boolean flag), real submit retry/backoff with idempotency
(so a retried submit can't double-submit), and a validated (not
guessed-at-45-seconds) inactivity timeout — likely configurable per-event
by whoever runs the pageant, not hardcoded.

## Phase 6 — multi-page refactor, guards, and preview mode

The single `index.html` (all 5 screens toggled via `hidden`) was split into
one HTML file per screen under `pages/`, each a real page navigation
(`window.location.href = '...'`, not a JS screen-switch). `index.html` at
the project root is now a **dev-only launcher**, not the app entry point a
judge would use.

- **Every page opens directly via `file://` — double-click, no server
  needed.** See `HANDOFF.md`'s "Direct-file (`file://`) compatibility
  audit" section for the full check (no ES modules, no `fetch`, no
  absolute paths, relative-filename navigation). `start-server.command`
  is available only as an optional convenience for testing the full
  persistent flow over `http://localhost`.
- **`?preview=1`** on any `pages/*.html` URL renders that page without its
  normal state guard, for visual review in isolation. It is display-only:
  it never writes to `localStorage` and never flips `isSubmitted`. A
  `submitted.html?preview=1` open right after a fresh reset (0/15 scored)
  still shows a mocked "15 contestants scored, submitted at 21:42" — that
  is intentional fake data for the screenshot, not a bug, and closing that
  tab leaves the real `0/15` state untouched.
- **`submitted.html`** is guarded: without `?preview=1` it redirects to
  `review.html` unless `isSubmitted` is already `true` in storage. There is
  still no way to reach a *real* (non-preview) Submitted screen except by
  actually completing all 15 and confirming the modal — the guard is a
  redirect, not a soft warning.
- **`scoring.html?id=N`** validates `N` against the real contestant list;
  an invalid/missing id (`?id=999`, `?id=abc`, no `id` at all) redirects to
  `contestants.html` rather than rendering a broken score sheet. In preview
  mode an invalid id instead falls back to contestant #1 so the page still
  has something real to show.
- **`review.html`** and **`contestants.html`** have no completion guard at
  all, by design (per the refactor brief) — they're the two screens meant
  to be opened at any completion level, including 0/15.
- The **dev panel** ("⚙ Prototype Controls") and the **launcher's "Reset
  Prototype State"** button are the only two ways to change state outside
  the normal judging flow. Both are visually distinct from the judge
  product (monospace, dashed borders, an explicit "dev/prototype only"
  label) and must not ship.

## What Phase 5 deliberately did NOT touch

No Result/Ranking engine, no Head Judge UI, no other-judges' scores, no
admin dashboard, no real backend/API/auth, and no Flutter code was written
in this phase — see the Phase 5 handoff report for the full audit findings,
score-entry recommendation, and remaining production risk list.
