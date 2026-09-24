# KREEN Judge Panel — HTML Prototype

**King & Queen of the Pacific 2026 — Preliminary Round judging**

> ⚠️ **This is a prototype, not the product.** Everything in `judge-prototype/`
> is static HTML/CSS/vanilla JS with no backend, no build step, and no
> framework. Its job is to be a **frozen UX/behavior reference** that a
> **Flutter production app** is built against — it is not meant to be
> ported, wrapped, or shipped as-is. See
> [**`_docs/flutter/FLUTTER-IMPLEMENTATION-HANDOFF.md`**](_docs/flutter/FLUTTER-IMPLEMENTATION-HANDOFF.md)
> before writing any Flutter or backend code.

## What this is

A multi-page prototype of the tablet judging app used by pageant judges to
score contestants, plus a companion Admin workspace used to configure
rounds, judges, contestants, rubric, monitoring, results, and advancement.

- **Judge flow** (the original, visually frozen 5 screens): Standby →
  Contestants → Scoring → Review → Submitted, now entered through a
  round-aware **My Rounds** screen.
- **Admin flow**: Overview, Rounds, Participants, Judges, Rubric,
  Monitoring, Results, Advancement, Audit, Settings — all prototype-only,
  built on mock data.
- **Mock Login → Mode Selector** (`index.html` → `mode.html`) gates which
  mode a fixture user can enter, based on mock capabilities. This is a
  UX simulation of permissions, **not real authentication or authorization**.

No real data leaves the browser. Everything is `localStorage`, seeded from
`assets/js/mock-data.js` and `admin/admin-data.js`.

## How to open it

No install, no server, no build. Open the HTML files directly in a
browser (`file://`), or double-click them from Finder/Explorer:

```text
judge-prototype/index.html   → mock Login → Mode Selector
judge-prototype/dev.html     → dev-only launcher: jump straight to any screen,
                                 reset prototype state, preview flows
```

Everything loads via relative `<script src>`/`<link>` tags — no ES modules,
no `fetch`/`XMLHttpRequest`, no absolute paths. This is a hard requirement,
not a style choice: see
[`_docs/decisions/adr-002-file-protocol-compatibility.md`](_docs/decisions/adr-002-file-protocol-compatibility.md).

An optional `start-server.command` is included for convenience only
(e.g. testing on a second device on the same network) — it is never
required for normal use or review.

## Structure

```text
judge-prototype/
  index.html, mode.html, dev.html   entry points (login sim, mode gate, dev launcher)
  pages/                            5 frozen Judge screens + my-rounds.html + results.html
  admin/                            Admin workspace (prototype-only, mock data)
  assets/js/state.js                single source of truth: formula, status, localStorage schema
  assets/js/session.js              fixture users + capabilities (mock auth simulation)
  _legacy-single-page/              earlier single-page version, kept for history only

_docs/
  flutter/FLUTTER-IMPLEMENTATION-HANDOFF.md   ← START HERE for the Flutter build
  design/design-system.md                     visual source of truth (tokens, components)
  product/                                    domain model, lifecycle, permissions, MVP scope
  architecture/                               file map, state ownership, API boundary target
  decisions/                                  ADRs — why multi-page+localStorage, why file://
  HANDOFF.md, PROTOTYPE-NOTES.md              technical handoff + prototype-only caveats
```

Full documentation index: [`_docs/README.md`](_docs/README.md).

## Before building the Flutter app

1. Read [`_docs/flutter/FLUTTER-IMPLEMENTATION-HANDOFF.md`](_docs/flutter/FLUTTER-IMPLEMENTATION-HANDOFF.md)
   in full — it defines scope, layer ownership, the domain/lifecycle model,
   the offline-first contract, and an explicit **"deliberately do not
   port"** list (no `localStorage` as the system of record, no `file://`
   tricks, no classic-script init pattern, no client-computed totals as
   official, no mocked authorization as real authorization).
2. Read [`_docs/product/mvp-scope.md`](_docs/product/mvp-scope.md) and
   [`_docs/product/lifecycle.md`](_docs/product/lifecycle.md) — Results,
   Ranking, Tie-break, Advancement, and Judge result visibility are
   **deferred pending business-rule approval**, not implemented rules.
   Nothing in this prototype's Results/Advancement screens should be
   treated as an approved formula.
3. Treat every backend guard described in
   [`_docs/architecture/api-boundary.md`](_docs/architecture/api-boundary.md)
   and [`_docs/api/api-boundary.md`](_docs/api/api-boundary.md) as
   mandatory server-side enforcement — this prototype only hides things
   in the UI, which is not a security or fairness boundary.
4. The 5 original Judge screens (Standby/Contestants/Scoring/Review/Submitted)
   are **frozen** — their visual design and interaction have already been
   through multiple review rounds. Any redesign needs explicit sign-off;
   see [`_docs/design/design-system.md`](_docs/design/design-system.md).

## Status

- **UX for the 5 Judge screens:** frozen, reference-quality.
- **Admin, multi-round, Results/Advancement UI:** prototype-only, built to
  demonstrate a candidate lifecycle model — not an approved production
  design.
- **Flutter, backend, API, database, real auth:** not started. Specification
  only, in `_docs/flutter/` and `_docs/product/`.

See [`_docs/tasks/tasks.md`](_docs/tasks/tasks.md) for the phase-by-phase
build log, and [`_docs/HANDOFF.md`](_docs/HANDOFF.md) for the detailed
technical handoff.

## Working on this repo

See [`CLAUDE.md`](CLAUDE.md) for the non-negotiable constraints (frozen
design, no new business features without explicit instruction, single
source of truth for score formulas, `file://` compatibility, branch-only
pushes) and the project's Karpathy principles.
