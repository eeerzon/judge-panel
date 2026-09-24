# Prototype entry flow

The normal `file://` entry is `judge-prototype/index.html` (Login). It uses a local UX fixture, not real authentication. After Sign In, `mode.html` derives available modes from the fixture's capabilities and renders only those modes. Choosing Admin opens `admin/index.html`; choosing Judge opens `pages/my-rounds.html`.

| Demo account | Username / email | Capabilities | Mode cards | Judge profile |
|---|---|---|---|---|
| Ersa | `ersa` / `ersa@kreen.test` | `admin:access`, `judge:score` | Admin, Judge | Explicitly linked to existing Judge 03 / Amanda Wijaya for this prototype |
| Amanda Wijaya | `amanda` / `amanda@kreen.test` | `judge:score` | Judge only | Judge 03 / Amanda Wijaya |
| Event Admin | `event-admin` / `admin@kreen.test` | `admin:access` | Admin only | None |

Any nonempty password is accepted for the local fixture; the Demo Access buttons bypass password entry. `assets/js/session.js` keeps `currentUser`, derived `availableModes`, and `currentMode` in the single `kreenPrototypeSession` localStorage key. Capabilities are re-derived from known fixtures on every read. This is navigation simulation, **not** an authorization or security boundary.

Ersa's Judge Mode intentionally uses the **same seeded Judge 03 profile and score sheet** as Amanda. My Rounds states “Judging as Amanda Wijaya.” This makes the relationship explicit for UX testing, but it is not a model for production accounts or score ownership. A separate Ersa Judge profile and sheet would require a product/data decision.

Mode switching changes `currentMode` without logging out. The Admin account area and Judge My Rounds expose switching only if the account has both capabilities. Log Out removes only `kreenPrototypeSession` and returns to Login; Admin configuration, event data, and Judge scores stay intact. Direct Admin/Judge page access checks the selected mode and redirects to Login or the selector. `preview=1` is a deliberate developer-only exception for visual page review.

The former launcher lives at `judge-prototype/dev.html`. Its preview links and Judge state reset remain developer utilities; neither is part of the normal Login flow. All routes use classic relative scripts, no fetch/modules/server. Production Flutter must replace the local fixture and guards with server-authoritative authentication, event-scoped capabilities, independent Judge profiles, and real session lifecycle.
