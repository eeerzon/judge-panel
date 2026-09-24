# Flutter Implementation Handoff — KREEN Judging

**Status:** Phase 7 specification only. No Flutter, backend, API, schema, or migration has been implemented.  
**UX status:** **FUNCTIONAL UX PROTOTYPE: FROZEN. VISUAL POLISH: REFERENCE QUALITY, NOT PIXEL-FINAL.**  
**Audience:** product, Flutter, backend, QA, and security teams. Review the [pending production decisions](../decisions/production-decisions-pending.md) before treating prototype policy as production policy.

## 1. Product and scope

One event contains event-level Contestant/Judge masters and ordered, independent judging rounds. Admin configures and operates rounds; assigned Judges score their own round-local sheets. The current UX demonstrates Preliminary → Top 10 → Final, governance, official results, visibility, advancement, and a mock Login → capability resolution → Mode Selector entry flow. It does **not** establish production architecture, trust boundaries, or authorization. The source prototype is under `judge-prototype/`; see [screen inventory](screen-inventory.md), [page mapping](prototype-mapping.md), and [prototype entry fixture](../product/prototype-entry-flow.md).

Judge Mode is an immersive, low-density, dark scoring flow designed tablet-landscape first. Admin Mode is an operational workspace designed tablet/desktop first. Preserve hierarchy and user intent, not HTML renderers or exact CSS pixels. The Judge's score remains private from other Judges. Admin monitoring is status-only unless `view_all_scores` is granted.

## 2. Target boundaries

| Layer | Owns | Does not own |
|---|---|---|
| Backend | Authentication, scoped capabilities, event/round configuration, authoritative score and submission revisions, lifecycle commands, result calculation/snapshot, advancement, audit, device revocation. | Client-only visual state. |
| Flutter domain/application | Typed models, use cases, local validation, commands/queries, sync coordination, derived presentation models. | Authority to finalize/submit/override independently. |
| Flutter durable local store | Cached bootstrap, Judge draft scores, pending commands, acknowledged revisions and sync metadata. | Official result truth or permission enforcement. |
| UI | Intent capture, navigation, accessibility, optimistic/pending/confirmed/locked feedback. | Business fact persistence or security boundary. |

Choose state-management, local database, routing, transport, and auth packages during the implementation design review—not by copying JS globals or `localStorage`. See [local storage](local-storage.md), [sync strategy](sync-strategy.md), and [API boundary](../api/api-boundary.md).

## 3. Navigation and screens

```text
Authentication → session / event capability resolution → Mode Selector
└─ App / authenticated Event context
├─ Admin Mode
│  ├─ Overview
│  ├─ Rounds → Round Workspace
│  │  ├─ Overview · Monitoring · Contestants · Judges · Criteria · Results · Settings
│  │  └─ contextual detail: Submission Detail · Result Detail · Advancement
│  ├─ Contestants Master · Judges Master
│  ├─ Live · Global Results
│  └─ More → Settings · Audit Log · mode/session actions
└─ Judge Mode
   ├─ My Rounds
   └─ Assigned Round → Standby → Contestants → Scoring → Review → Submitted
                        └─ Official Results (only after backend visibility gate)
```

Global Admin navigation and Round tabs are **different state**: a Round Workspace screen keeps global `Rounds` active while changing only the round tab. `Contestants Master` is not `Round Contestants`; `Global Results` is not `Round Results`; event Live is not Round Monitoring. Keep Event and Round context persistent across round tabs. Suggested typed route identities (not final router choice):

| Level | Candidate route |
|---|---|
| Admin global | `/admin`, `/admin/rounds`, `/admin/contestants`, `/admin/judges`, `/admin/live`, `/admin/results`, `/admin/audit` |
| Admin round | `/admin/rounds/:roundId`, `/monitoring`, `/contestants`, `/judges`, `/criteria`, `/results`, `/settings` beneath that round |
| Admin contextual | `/admin/rounds/:roundId/submissions/:submissionId`, `/results/:contestantId`, `/advancement` |
| Judge | `/judge/rounds`, `/judge/rounds/:roundId/standby`, `/contestants`, `/scoring/:contestantId`, `/review`, `/submitted`, `/results` |

Route guards fetch authoritative session/assignment/capabilities and lifecycle state. A deep link must not bypass result visibility, own-sheet privacy, or round lock. Preserve navigation history across rounds and return to My Rounds from submitted/read-only views.

## 4. Responsive implementation rules

- Large landscape/desktop: persistent Admin sidebar, bounded content width and generous gutter; Round tabs within the workspace.
- Tablet landscape: compact sidebar and readable operational tables/cards. Admin is tablet/desktop first.
- Tablet portrait/mobile: bottom global navigation with More for secondary destinations; independent horizontally scrollable/adaptive Round tabs. Keep safe-area and keyboard insets, 48 dp minimum important touch targets, non-overlapping CTA/content, and accessible focus/order.
- Judge is tablet-landscape first, but portrait must remain functional. Keep immersive dark presentation, large scoring controls, clear status, and no Admin-density shell.
- Define breakpoints from available width, text scale, orientation, and actual devices. Do **not** port CSS media-query pixel values as Flutter constants. Validate desktop, tablet landscape/portrait, and phone with real devices and accessibility text scaling before declaring visual parity.

The prototype has not been established as pixel-final; see [widget map](widget-map.md) and the existing design-system docs for semantic tokens and states.

## 5. Domain and lifecycle

Event owns Contestant/Judge masters and Round sequence. Each Round owns participation, Judge assignments (`required`, active/excused/removed), versioned criteria, ScoreSheets, result, visibility, and advancement relation. ScoreSheet identifies one Judge + Round; Score identifies Contestant + Criterion inside it. Do not duplicate master records in Round assignments. See [domain model](../product/domain-model.md).

Round: `Draft → Open → Closed → Finalized`. Draft→Open requires contestants, assigned Judges including at least one Required, valid rubric and 100% effective scored weight, no blockers. Open→Closed requires all active Required submissions acknowledged or explicitly excused under approved policy. Closed→Finalized requires valid results, included Judge set, resolved governance, and explicit tie acknowledgement if applicable. No direct Open→Finalized or normal edit after Finalized.

ScoreSheet: `Not Started → In Progress → Submitted → Reopened → Resubmitted`. `Excused` is an assignment governance state, **not** a ScoreSheet state. Only an authorized actor can reopen with reason/audit; Judges cannot self-reopen. Local `pending submit` is distinct from server-confirmed `Submitted`.

Result: `Unavailable → Provisional Admin Result → Finalized Official Snapshot`; Judge visibility is separate `Hidden ↔ Visible` only after Finalized. Advancement is separate again: `Pending → Confirmed`, without becoming a fifth Round status. See [lifecycle](../product/lifecycle.md).

## 6. Permissions and sessions

`super_admin`, `event_admin`, `head_judge`, and `judge` are baseline **bundles** of scoped capabilities, not hardcoded UI branches. Flutter consumes capabilities in an authenticated session/bootstrap and uses them for affordances; backend rechecks every query/command with Event/Round/Judge scope. Required capabilities include `manage_event`, `manage_round`, `manage_contestants`, `manage_judges`, `manage_criteria`, `open_round`, `close_round`, `view_live_monitoring`, `view_all_scores`, `view_results`, `finalize_results`, `reopen_submission`, `manage_result_visibility`, `score_round`, `submit_score_sheet`, `manage_advancement`, and `view_audit_log`. Advancement override/reset may require separate capabilities or approvals—decision pending. See [permission matrix](../product/permission-matrix.md).

Admin session: authenticated user, selected Event, scoped capabilities. Judge session: authenticated Judge, assigned rounds, own ScoreSheets, and a revocable device/session context. Future `DeviceSession` concept: `deviceId`, `judgeId`, `eventId`, `authenticatedAt`, `lastSyncAt`, `revokedAt`. Provider, pairing, and session lifetime remain undecided. No secret should live in client source or logs.

## 7. Offline-first Judge contract

Bootstrap an assigned Open round while online → transactionally cache roster/rubric/assignment/sheet version → persist every valid score edit locally before showing Saved → enqueue ordered mutation → retry with backoff → apply server acknowledgement/version → submit only after server validation of the complete sheet. A score must survive app termination/restart. Display **Saved locally**, **Syncing**, **Synced**, **Conflict**, and **Submit pending** distinctly. Offline draft work is allowed only against a previously authorized, cached round; offline presence alone does not create new authorization.

Submit is idempotent using a stable idempotency key. Ambiguous network failures retry the same command/key. Client cannot mark official Submitted before acknowledgement. A stale `scoreSheetVersion` produces conflict: stop overwrite, fetch latest, compare, and resolve explicitly. Details in [sync strategy](sync-strategy.md).

## 8. Results and advancement: prototype policy baseline, not final production policy

**PROTOTYPE POLICY:** official Judge eligibility is assigned + Required + Submitted/Resubmitted, excluding Optional, Excused, Removed. Combined Score is the arithmetic mean of each eligible Judge's contestant total (0–100), displayed to two decimals. Equal two-decimal scores share rank; contestant number only stabilizes display. A tie at the advancement cutoff requires explicit selection/reason. Backend must recalculate totals and eligibility; never trust client totals or ranking.

Closed may expose provisional results to authorized Admin only. Finalize creates an immutable, versioned official snapshot containing contestant identity/ID, combined score, rank/tie state, Judge breakdown and included set, calculation/rubric metadata, `finalizedAt`, and `finalizedBy`. Official pages read the snapshot, never recalculate from mutable sheets. Result visibility is per Round, defaults OFF, and Judge queries return only rank/contestant/combined score when assignment is valid, round Finalized, visibility ON, and access still valid. The backend must not send other Judge identities/scores to Judge clients.

Advancement references a finalized result snapshot and records source/target rounds, target count, selected contestants, Top-N/manual method, actor/time, and reasons/adjustments. It **never changes the official result**. Confirmed selections populate target RoundContestant assignments; target Judge assignments/rubric are independent (optional explicit copy); each Round starts with a separate blank ScoreSheet and result. `carryForwardScores = false` in this baseline. Withdrawal/replacement and reset require audited reasons while target is Draft under prototype rules. See [pending decisions](../decisions/production-decisions-pending.md).

Conceptual production records (not schema): `Advancement {sourceRoundId, targetRoundId, resultSnapshotId, method, targetCount, confirmedBy, confirmedAt}` and `AdvancementContestant {advancementId, contestantId, sourceRank, selected, overrideReason}`. Preserve adjustment/reset history separately rather than rewriting an old decision without trace.

## 9. API, errors, security, audit

The backend owns command guards, calculation, version checks, idempotency, authorization, and append-only audit. Flutter owns UX and local durability. Candidate resource/command groups are specified in [API boundary](../api/api-boundary.md); routes/payloads are proposals, not contracts. Standard error concept: `{code, message, details, requestId}`. Minimum codes: `ROUND_NOT_OPEN`, `SUBMISSION_ALREADY_SUBMITTED`, `SUBMISSION_REOPENED`, `ROUND_CLOSED`, `VERSION_CONFLICT`, `NOT_ASSIGNED`, `RESULT_NOT_VISIBLE`, `OFFLINE_PENDING`, `VALIDATION_ERROR`.

Audit events must be server-generated for `round_opened`, `score_submitted`, `submission_reopened`, `score_resubmitted`, `judge_excused`, `round_closed`, `result_finalized`, `result_visibility_changed`, `advancement_confirmed`, and `advancement_reset`. Client Audit UI is read-only. Local prototype audit entries are not production evidence.

## 10. Deliberately do not port

Do not port `localStorage` blobs, `file://` compatibility, classic script initialization, URL query hacks, JS renderer structure, mocked authorization/audit, hardcoded demo names/scores, or CSS breakpoint numbers. Do not use a client-computed total as official. Preserve UX hierarchy, domain rules as *reviewable candidates*, screen states, and user-tested visual intent.

## 11. Proposed implementation order (requires separate approval)

P0 Flutter foundation/theme/routing/responsive shell → P1 auth/session/capabilities → P2 Judge My Rounds/bootstrap → P3 durable offline scoring → P4 review/submit/sync → P5 Admin read-only monitoring → P6 Admin configuration → P7 governance → P8 results/finalization → P9 advancement → P10 hardening, device QA, security and release checks. Backend schema and endpoint contracts must be reviewed separately before coding. The recommended **first coding phase is P0 only**, after handoff/production decisions are approved.

## 12. Handoff acceptance checklist

- Screen, widget, route, action, loading/empty/error/offline/locked states reviewed against actual prototype.
- Production decisions and capability grants approved by product/operations/security.
- Backend contracts define versioned rubric/sheets, authoritative totals, idempotency, error codes, and data minimization for Judge Results.
- Local persistence and recovery tested for process death, offline operation, stale versions, and revocation.
- Real-device usability verified; reference-quality HTML is not treated as pixel-final.
- Prototype docs are planning inputs only; production documentation tier/security/test plans must be upgraded before implementation.
