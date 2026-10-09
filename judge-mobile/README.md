# KREEN Judge — Flutter (tablet, landscape)

Judge + Admin app for tablets. UI/UX is a port of the frozen HTML prototype in
`../judge-prototype/` (Judge: `../_docs/design/design-system.md`,
`../_docs/srs/fr-judging-flow.md`; Admin: `../_docs/design/admin-design-system.md`,
`../_docs/srs/fr-admin-configuration.md`). Judge Mode uses the KREEN judge API;
Admin Mode uses the Admin API that exists so far (events, rounds, contestants)
and prototype data for the rest.

## Run

```bash
flutter pub get
flutter run                                     # tablet / emulator, landscape
flutter run --dart-define=KREEN_DEV_PANEL=true  # + "Prototype Controls" strip
flutter run --dart-define=KREEN_API_BASE_URL=https://other-host/api/v1
flutter test
```

Default API: `https://newvote.kreenconnect.com/api/v1`. Sign in with a judge
account (email + password). A judge only sees rounds an admin assigned to them.

Orientation is locked to landscape (Android `sensorLandscape`, iOS Info.plist,
`SystemChrome` in `main.dart`); layouts still adapt to portrait.

## Start-up

Native launch screen (white + KREEN logo; Android `launch_background.xml`,
Android 12+ `values-v31`, iOS `LaunchScreen.storyboard`) → `SplashLogoPage`
(same white + logo + app version, ≥2 s) → validates a saved session with
`GET /judge/rounds` for judge accounts (401 → Login) → **Mode Selector**, or
**Login** without a session. Replace the logo in `assets/images/KreenOriginal.png` and the
native copies (`res/drawable-*/splash_logo.png`, `LaunchImage*.png`) together.

App icon: `assets/images/kreenmobileiconrounded.png`, resized into
`android/app/src/main/res/mipmap-*/ic_launcher.png` (rounded, transparent
corners) and `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` (flattened on
white — iOS icons must not have transparency).

## Admin Mode (Mode Selector → Open Admin)

Port of `judge-prototype/admin/*.html`, same layout rules as `admin.css`:
sidebar in landscape (236px, 208px ≤1100px), context bar, and a
Home/Rounds/Live/Results/More bottom bar on screens ≤760px or portrait.

| Prototype page | Flutter screen (`lib/admin/screens/`) |
|---|---|
| — (API is multi-event) | `events_screen` — event picker, first Admin page |
| index / rounds | `overview_screen`, `rounds_screen` |
| round / monitoring / submission-detail | `round_overview_screen`, `monitoring_screen` (+ judge drawer), `submission_detail_screen` |
| round-contestants / round-judges / criteria | `round_contestants_screen`, `round_judges_screen`, `criteria_screen` |
| round-results / result-detail / advancement | `round_results_screen`, `result_detail_screen`, `advancement_screen` |
| contestants / judges | `masters_screen` |
| live / results / settings / audit | `live_screen`, `global_results_screen`, `settings_screen`, `audit_screen` |

### Admin API used (`/judge/admin/...`)

| Endpoint | Used by |
|---|---|
| `GET dashboard?page&search` | Events list (search, "Load More" pages via `meta`) |
| `GET events/{idVote}` | Opening an event: header (name, year) + its rounds |
| `POST events/{idVote}/rounds` | "+ Create Round" drawer (Overview / Rounds), then reload |
| `GET contestants?id_vote` | Contestants master (`profesi` is the card's second line) |
| `GET judges` (all pages) | Judges master, loaded with the event; `capabilities` shown as read-only Roles |
| `POST judges` / `PATCH judges/{id}` | Judge drawer Save (password required on add; empty = unchanged on edit) |
| `DELETE judges/{id}` | Judge drawer Delete (with confirmation) |
| `PUT judges/{id}/roles` | `AdminStore.setJudgeRoles` — no screen yet (valid roles/scopes to be agreed) |

| `GET rounds/{id}` + `/contestants` + `/judges` + `/criteria` + `/monitoring` (+ `/results` when closed/finalized, `/advancement` when finalized) | Loaded for every round when the event opens and again whenever a round page opens (`AdminStore.loadRound`) |
| `PATCH` / `DELETE rounds/{id}` | Round "Edit" drawer (Delete only for Draft) |
| `POST rounds/{id}/open` · `/close` · `/finalize` | Open Round · Close Round · Finalize Results |
| `POST` / `DELETE rounds/{id}/contestants[/{roundContestantId}]` | Round Contestants add / remove (the difference is sent) |
| `POST` / `DELETE rounds/{id}/judges[/{judgeId}]` | Round Judges "Assigned" toggle; Monitoring "Remove Assignment" |
| `POST` / `PATCH` / `DELETE rounds/{id}/criteria[/{criteriaId}]` | Criteria drawer Save / Delete; Copy Configuration |
| `POST rounds/{id}/score-sheets/{sheetId}/reopen` | Monitoring "Reopen Submission" (every submitted sheet of that judge) |
| `GET rounds/{id}/results/{roundContestantId}` | Result Detail and Submission Detail per-judge criterion scores (closed/finalized only — 404 while open) |
| `PATCH rounds/{id}/results/visibility` | Judge Results Visibility toggle |
| `POST rounds/{id}/advancement` | Advancement "Confirm" (`round_contestant_ids` of the source, `reason`, `include_favorit: false`); a server block (`can_confirm = false`) shows its `blocking_reason` as the existing validation message |
| `DELETE rounds/{id}/advancement?reason=` | Reset Advancement (reason 3–1000 characters) |
| `GET` / `PATCH events/{idVote}/settings` | Loaded with the event (`AdminStore.serverSettings` / `saveServerSettings`); no screen — the Settings page UI is unchanged |

Adjusting an advanced Draft target (withdrawal) has no endpoint: the roster
difference is sent with the round contestant endpoints; the reason is not
stored. Still local / unavailable: Required/Optional per judge (read-only with
the API), Excuse / Restore judge, tie acknowledgement, device connection
(`/devices` → 501), audit log (`events/{idVote}/audit-log` → "Belum
tersedia"; the Audit page keeps the local log). Criterion hierarchy (parent) and `step` are read from the
API but not sent (not in the create/update body).

`POST contestants` answers "Belum tersedia — menunggu skema tabel judging"
(PATCH/DELETE likewise not ready), so contestant add/edit stays on the device
and is replaced by server data on the next reload. The judge "Display Number"
is app-only (the API has none).

`GET events/{idVote}/rounds` is implemented in `AdminApi` but not needed yet
(the event detail already carries the rounds).

The API is the authority for everything it returns (events, rounds, round
contestants/judges/criteria, monitoring, results, advancement info) on every
load. Placeholder round data sized from the round counts only shows if a
round fails to load. Local-only changes are kept per event on the device
(`kreenAdminConfiguration.<idVote>`) and replaced on the next reload.

All Admin rules (effective weight, readiness, open/close guards, reopen /
excuse / restore / remove, results, tie acknowledgement, finalize,
visibility, advancement, copy configuration) live **only** in
`lib/admin/admin_store.dart` — a port of `admin-domain.js`. Without an API
(tests) it runs on the prototype seed (3 rounds, 15 contestants, 7 judges).
As more Admin endpoints arrive, replace the matching store command bodies with
API calls; screens do not change. The backend stays the authority
for every rule and capability (`../_docs/api/api-boundary.md`).

Not ported: the contestant photo file picker (photo by URL only).

Access follows the login's `actor_type`. The Mode Selector is always shown
and lists only the workspaces the account may open:

| `actor_type` | Mode Selector cards | Mode switch buttons |
|---|---|---|
| `owner` | Admin + Judge | both ways |
| `admin` | Admin | none |
| `judge` (also missing/unknown) | Judge | none |

A route to a workspace the account may not open shows the Mode Selector
instead. `capabilities` is not used yet. Known backend issue: `/judge/rounds`
currently answers 401 to owner tokens, which ends the session when an owner
opens Judge Mode (owners are allowed to judge — to be fixed server-side).

## API used (`/judge/...`)

| Endpoint | Used by |
|---|---|
| `POST auth/login` | Login → bearer token (~1 h, no refresh: re-login) + `actor_type` (owner / admin / judge) |
| `GET rounds` | My Rounds (event name from `vote.judul_vote`) |
| `GET rounds/{id}` + `/contestants` + `/criteria` + `/score-sheet` | Loaded together when a round opens (`RoundGate`) |
| `POST rounds/{id}/score-sheet` | Every valid score/note edit (debounced, batched per contestant) |
| `POST rounds/{id}/review` | Opening Review & Submit (refreshes statuses/values) |
| `POST rounds/{id}/submit` | Submit, with a stable `idempotency_key` reused across retries |
| `GET rounds/{id}/results` | Official Results (403 until the admin publishes them) |

Notes on the live responses (they differ from the published examples):
`access_token` is a string, `judge.id`/`expires_in` are integers, contestant
identity is in `contestants[].finalis` (`nama_finalis`, `nomor_urut`,
`poster_finalis`, `profesi`), criteria carry their own `min_points`/`max_points`
/`step`/`weight` (e.g. 0–100), and errors are `{message, errors?}` with 401 /
403 / 422. Captured bodies are in `test/api_parsing_test.dart`.

## How the prototype logic maps to the API

- **Total score** (display only, server is authoritative): Σ(raw / max × weight),
  normalised to /100 — identical to the prototype's Σ(value × weight)/10 on a
  1–10 rubric. Still null until every criterion is filled (FR-2).
- **Status** Scored / Draft / Not Scored is derived from filled criteria (FR-1).
- **Validation** (FR-3) uses each criterion's min/max/step. Missing `step` →
  0.25 on a ≤10 scale, otherwise 1. Quick score 7/8/9/10 only on a criterion
  named "Confidence" with a 1–10 scale (FR-4).
- **Submitted / locked**: every contestant row has `sheet_status` `submitted`
  (or `resubmitted`/`locked`); a `reopened` row makes the round editable again.
- **Round access**: listed by the API = assigned; scoring only while `open`
  and not submitted; a submitted round stays viewable read-only.
- **Notes**: one note per contestant is sent as `comment` on that
  contestant's score rows (the API has a comment per criterion).

## Offline & sessions

Each edit is written to a local draft first (SharedPreferences, per judge)
and marked dirty; a debounced `POST score-sheet` sends the dirty contestants.
Footer states: `Saving…` → `Saved ✓`; no network → `Saved on device` + offline
banner + retry with backoff (drafts survive restarts); server rejection →
`Unable to save` with the server message and a Retry. A 401 on any call ends
the session and returns to Login; unsent drafts stay on the device.

Before production: move the token to secure storage, confirm with the
backend whether `raw_score: null` is accepted for clearing a score, whether
`/review` has side effects, and the Judge results payload (the current
response has no ranking list; the screen handles both).

## Structure

| Dart | Role |
|---|---|
| `lib/api/api_client.dart` | HTTP + JSON envelope + `ApiException` (401 → logout hook) |
| `lib/api/judge_api.dart` | Typed Judge endpoints (`JudgeApi` interface, `HttpJudgeApi`) |
| `lib/api/admin_api.dart` | Admin endpoints (`AdminApi`, `HttpAdminApi`) |
| `lib/domain/models.dart` | Models parsed from API JSON; criteria → sections |
| `lib/state/judge_store.dart` | **Only** place for total formula + status derivation; round cache, drafts, sync queue, submit |
| `lib/state/session_store.dart` | Login / token / expiry |
| `lib/navigation/judge_nav.dart`, `lib/widgets/round_gate.dart` | Routes + guards (loading, 403, not open) |
| `lib/screens/*` | Splash, Login, Mode Selector, My Rounds, Standby, Contestants, Scoring, Review, Submitted, Results |
| `lib/admin/*` | Admin Mode: store (rules), nav/routes, shell + round workspace, event picker + 17 screens |
| `test/support/fake_judge_api.dart`, `fake_admin_api.dart` | In-memory APIs used by store + flow tests |
