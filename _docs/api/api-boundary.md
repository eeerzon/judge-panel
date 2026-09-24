# API Domain Boundary — Candidate Contract, Not Implementation

**Status:** route shapes below are candidates only. No API, database, migrations, auth provider, transport choice, or generated client is approved by this document. The backend is the authoritative enforcement boundary; Flutter may cache/read/queue but cannot self-authorize transitions.

## Resource/command groups

| Group | Backend responsibility | Candidate operations (illustrative) |
|---|---|---|
| Auth/session/device | Authenticate, issue scoped capabilities, expire/revoke sessions/devices | Session/bootstrap/refresh/revoke; `GET /api/v1/me` |
| Events | Event identity, branding, timezone, membership/scope | `GET /events/{id}/overview`, event query/update |
| Rounds | Ordered configuration, lifecycle guards and transitions | `GET /events/{id}/rounds`, `GET /rounds/{id}`, `POST /rounds/{id}/open`, `/close` |
| Contestants | Event master and RoundContestant participation | Master CRUD; Round roster/assignment query/update |
| Judges | Event master, RoundJudgeAssignment, Required/Optional/Excused/Removed | Assignment query/update; `POST /judge-assignments/{id}/excuse`/restore/remove |
| Criteria | Versioned one-level rubric, effective scored weight validation | Round criteria query/update; validation before Open |
| Score Sheets | One Judge+Round sheet, own access, version and state | `GET /api/v1/score-sheets/{id}`, `GET /api/v1/rounds/{id}/bootstrap` |
| Scores | Validate per-criterion values/notes; recalculate totals; version check | `PUT /api/v1/score-sheets/{id}/scores` (candidate batch/update semantics) |
| Submissions | Idempotent submit, reopen with reason, resubmit history | `POST /api/v1/score-sheets/{id}/submit`, `POST /submissions/{id}/reopen` |
| Results | Provisional calculation for authorized Admin; immutable finalize snapshot; per-Round visibility | `GET /rounds/{id}/results`, `POST /rounds/{id}/finalize`, `POST /rounds/{id}/results/visibility` |
| Advancement | Confirm selection from finalized snapshot, target assignment, adjustment/reset | `POST /rounds/{id}/advancement`, advancement query/adjust/reset |
| Audit | Append-only server event log, permission-filtered queries | `GET /events/{id}/audit` with cursor/filter |

Judge candidates additionally include `GET /api/v1/me/rounds` and `GET /api/v1/rounds/{id}/results`. Exact route prefix, HTTP methods, command boundaries, payload schema, pagination, and versioning require a separate API design review. `GET Judge Results` must be backend-filtered to rank/contestant/combined score, not Admin breakdown with fields hidden by Flutter.

## Command invariants

- All commands require authenticated session, scoped capability, and current resource/version checks; UI visibility is never authorization.
- Draft→Open validates contestant assignment, at least one active Required Judge, criteria validity and 100% effective scored weight. Open→Closed validates Required submission/excuse policy. Closed→Finalized validates result and tie/governance policy, then atomically stores immutable snapshot and audit.
- Score writes validate current assignment, Round Open, ScoreSheet editable, criterion/rubric version, range/step, and expected sheet version. Backend computes totals. Submit is idempotent and produces one authoritative submission event.
- Reopen and Excuse require reason/capability/audit. Advancement requires finalized snapshot and eligible Draft target; it writes a **separate** advancement decision and target assignment without modifying official result. Reset/adjustment policy remains under review.
- Visibility is per Round, default OFF, only switchable after Finalized. Judge result access requires current assignment, Finalized, visibility ON, and valid capability/session **on every request**.

## Query and offline boundaries

Queries must be scope-filtered server-side: Judge receives only assigned rounds, current roster/rubric, own sheet, and authorized redacted result. Admin monitoring is status-only unless `view_all_scores`. Audit is permission-filtered, immutable, and paginated. Device revocation or assignment removal invalidates future protected queries/writes. A local cache may support offline draft scoring against a previously authorized bootstrap, but cannot make official Open/Close/Submit/Reopen/Finalize/Advance/visibility decisions while disconnected in the baseline.

## Versioning, idempotency, error envelope

Define stable IDs, `roundVersion`, `rubricVersion`, `scoreSheetVersion`, result `snapshotId`, and advancement version before implementation. Use optimistic concurrency; stale writes return a conflict rather than last-write-wins. Conceptual submit request includes `idempotencyKey`; repeated attempts return the same outcome. Other sensitive commands may also need idempotency keys.

Standard error concept:

```json
{"code":"VERSION_CONFLICT","message":"The score sheet changed.","details":{"resource":"scoreSheet"},"requestId":"..."}
```

Minimum machine-readable codes: `ROUND_NOT_OPEN`, `SUBMISSION_ALREADY_SUBMITTED`, `SUBMISSION_REOPENED`, `ROUND_CLOSED`, `VERSION_CONFLICT`, `NOT_ASSIGNED`, `RESULT_NOT_VISIBLE`, `OFFLINE_PENDING`, `VALIDATION_ERROR`. Add permission denied, rubric changed, device revoked, and idempotency mismatch in contract review. Messages must be safe for Judge clients and avoid leaking other Judge scores/identities.

## Production security and audit

No client secrets, trusted totals, mock identities, or local audit as authority. Capabilities are enforced server-side for every action; sensitive reads are minimized. Finalized snapshots are immutable; corrections require a separately approved versioning/override protocol. Audit is append-only and generated in the same authoritative operation as the state change. Required events include `round_opened`, `score_submitted`, `submission_reopened`, `score_resubmitted`, `judge_excused`, `round_closed`, `result_finalized`, `result_visibility_changed`, `advancement_confirmed`, and `advancement_reset`.
