# Prototype → Flutter Mapping

Map of **every HTML page** under `judge-prototype/admin/` and `judge-prototype/pages/`. Flutter targets are screen concepts, not file-by-file ports. The shared shells replace duplicated page bootstrap code. See [screen inventory](screen-inventory.md) for navigation/state requirements and [widget map](widget-map.md) for component contracts.

## Admin HTML (17)

| HTML page | Flutter screen | Shared widgets | Server data | Local/UI data | Important actions |
|---|---|---|---|---|---|
| `admin/index.html` | `AdminOverviewScreen` | AdminShell, EventContextHeader, StatCard, DataRowCard | Event, ordered Rounds, readiness, monitoring summary | Selected Event, freshness | Enter current Round/Live |
| `admin/rounds.html` | `RoundsScreen` | AdminShell, StatusBadge, DataRowCard | Round order/status, advancement summary | Search/filter | Enter Round; future Draft creation policy |
| `admin/round.html` | `RoundOverviewScreen` | AdminShell, RoundWorkspaceHeader, RoundTabs, ReadinessChecklist, ConfirmationDialog | Round, assignments, criteria validity, submission readiness | Active tab, dialog | Open/Close, configure, monitoring/results |
| `admin/monitoring.html` | `RoundMonitoringScreen` | RoundWorkspaceHeader, RoundTabs, JudgeCard, StatCard | Scoped submission/progress/connection | Search/filter, freshness | Open Submission Detail |
| `admin/submission-detail.html` | `SubmissionDetailScreen` | RoundWorkspaceHeader, ResultBreakdown-like score detail, ReasonDialog | Authorized one-Judge sheet/history | Expanded rows/dialog | Inspect, Reopen/Excuse if permitted |
| `admin/round-contestants.html` | `RoundContestantsScreen` | RoundWorkspaceHeader, ContestantCard, ReasonDialog | Event master, RoundContestant IDs, advancement origin | Search/selection | Draft assign/unassign, reasoned adjustment |
| `admin/round-judges.html` | `RoundJudgesScreen` | RoundWorkspaceHeader, JudgeCard, StatusBadge | Judge master, RoundJudgeAssignment | Search/toggle draft | Draft assignment and Required flag |
| `admin/criteria.html` | `CriteriaConfigurationScreen` | RoundWorkspaceHeader, DataRowCard, WarningPanel, drawer/form | Versioned rubric, validation | Form draft, hierarchy selection | Add/edit scored/non-scored criteria |
| `admin/round-results.html` | `RoundResultsScreen` | RoundWorkspaceHeader, ResultsTable, StatCard, WarningPanel, ConfirmationDialog | Provisional Admin result or official snapshot, visibility, advancement | Tie acknowledgement dialog | Finalize, visibility, enter advancement |
| `admin/result-detail.html` | `ResultDetailScreen` | RoundWorkspaceHeader, ResultBreakdown | Authorized contestant result and Judge inclusion | Expanded criterion rows | Inspect only |
| `admin/advancement.html` | `AdvancementSelectionScreen` | RoundWorkspaceHeader, AdvancementSelectionRow, AdvancementPreview, ReasonDialog | Finalized snapshot, next Round/count | Unconfirmed selection/reason/preview | Confirm explicit advancement |
| `admin/contestants.html` | `ContestantsMasterScreen` | AdminShell, ContestantCard, drawer/form | Event Contestant master + assignment summary | Search/filter/form | Add/edit master |
| `admin/judges.html` | `JudgesMasterScreen` | AdminShell, JudgeCard, drawer/form | Event Judge master + assignment summary | Search/filter/form | Add/edit master |
| `admin/live.html` | `LiveOperationsScreen` | AdminShell, StatCard, JudgeCard | Open Round and status-only monitoring | Filter/freshness | Enter Round Monitoring |
| `admin/results.html` | `GlobalResultsScreen` | AdminShell, DataRowCard, StatusBadge | Per-Round result status/snapshot summary | None beyond navigation | Enter Round Results; no advancement controls |
| `admin/audit.html` | `AuditLogScreen` | AdminShell, AuditTimeline | Server append-only audit | Filter/cursor | Query/view only |
| `admin/design-system.html` | `DesignSystemGallery` **dev-only** | Component gallery | None | Showcase variants | Not a production destination |

Admin Round Settings is a tab placeholder in the prototype, not an HTML business screen. Define scope before implementing `RoundSettingsScreen`.

## Judge HTML (7)

| HTML page | Flutter screen | Shared widgets | Server data | Local/UI data | Important actions |
|---|---|---|---|---|---|
| `pages/my-rounds.html` | `MyRoundsScreen` | JudgeRoundShell, StatusBadge, round cards | Assigned Rounds, own submission status, permitted result visibility | Cached round summary/freshness | Enter Open; view own submission/results |
| `pages/standby.html` | `StandbyScreen` | JudgeRoundShell, SubmissionStatus | Event/Round/Judge bootstrap and assignment | Cached bootstrap, inactivity UI | Enter Contestants |
| `pages/contestants.html` | `JudgeContestantsScreen` | JudgeRoundShell, ContestantCard, SubmissionStatus | Round roster, own sheet reference | Derived own score status, search/filter | Select contestant |
| `pages/scoring.html` | `ScoringScreen` | JudgeRoundShell, ScoreInput, ScoreSummary, SubmissionStatus | Versioned rubric, own acknowledged sheet | Durable draft scores/notes, queue, focus | Score and navigate; never direct official submit |
| `pages/review.html` | `ReviewSubmitScreen` | JudgeRoundShell, ScoreSummary, ConfirmationDialog | Own sheet/version and required completeness | Local draft and sync state | Review; idempotent submit intent |
| `pages/submitted.html` | `SubmittedScreen` | JudgeRoundShell, SubmissionStatus | Server-acknowledged own submission/history | Cached acknowledgement | Read-only own sheet; return My Rounds |
| `pages/results.html` | `JudgeRoundResultsScreen` | JudgeRoundShell, ResultsTable (redacted variant) | Backend-filtered rank/contestant/combined score | Short-lived cache only if approved | View when Finalized+visible+assigned |

`judge-prototype/index.html` and `mode.html` now provide a **mock** Login and capability-driven Mode Selector. `dev.html` holds the developer launcher. These pages map to target Login/Session Resolution/Mode Selection screens, but the local `session.js` fixture is not production authentication, authorization, or device/session management. The target still requires an approved auth provider, server-scoped capabilities, independent account-to-JudgeProfile linkage, and session lifecycle policy.

## Prototype constructs to discard

`admin-domain.js`, `state.js`, and `session.js` localStorage blobs, global `window` objects, `file://` relative-script bootstrapping, query-string preview/state hacks, seeded Judge 03 and deterministic score references, mock audit entries, frontend capability checks, and current CSS media-query values are **not** Flutter architecture. Recreate the domain boundaries and screen intent with typed repositories/use cases, durable local persistence, backend enforcement, and real sync. The prototype launcher is `judge-prototype/dev.html`, never a production route.
