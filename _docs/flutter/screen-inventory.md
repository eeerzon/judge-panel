# Screen Inventory — Prototype → Flutter

**Entry update:** `judge-prototype/index.html` is now a mock Login and `mode.html` is a capability-driven Mode Selector; `dev.html` is the developer launcher. These are UX references only. Admin Round Settings remains a placeholder. Earlier page counts below are historical and may need a full inventory refresh before Flutter scoping.

Every product screen needs Loading, Empty (where a collection can be empty), Error with retry, and Offline/freshness feedback. Admin offline may show cached read-only data but cannot claim a command succeeded; Judge cached scoring is durable offline. Locked/read-only states must use backend lifecycle/capability, not just disabled buttons. The table lists additional critical states; `L/E/O/X` means Loading/Empty/Offline/Error baseline applies.

## Admin screens (18 including conceptual Settings)

| Prototype | Flutter target / nav level | Primary data | Actions | Critical states |
|---|---|---|---|---|
| `admin/index.html` | `AdminOverviewScreen` / Global Home | Event overview, current Round, readiness, recent monitoring | Open Round workspace; navigate | L/E/O/X; no active round; current stage Draft/Open/Closed/Finalized |
| `admin/rounds.html` | `RoundsScreen` / Global Rounds | Ordered Rounds, progression, readiness/advancement | Select Round; create future Draft if approved | L/E/O/X; no rounds; progression pending/confirmed |
| `admin/round.html` | `RoundOverviewScreen` / Round Overview | Round, readiness, assignments, criteria summary | Open, Close, configure, view monitoring/results | L/E/O/X; Draft setup blockers; Open close blockers; Closed; Finalized locked |
| `admin/monitoring.html` | `RoundMonitoringScreen` / Round Monitoring | Assignments, submission/progress/connection status | Filter; open Submission Detail | L/E/O/X; Open live; Closed/Finalized read-only; stale heartbeat |
| `admin/submission-detail.html` | `SubmissionDetailScreen` / Round Monitoring detail | One Judge ScoreSheet, scores, history, assignment | Inspect; reopen/exception via capability | L/E/O/X; not found; Submitted/Reopened/Resubmitted; Closed locked; no `view_all_scores` |
| `admin/round-contestants.html` | `RoundContestantsScreen` / Round Contestants | Event Contestant master + RoundContestant IDs + advancement source | Search, assign/unassign; reasoned adjustment | L/E/O/X; Draft editable; confirmed advancement warning; Open+ locked |
| `admin/round-judges.html` | `RoundJudgesScreen` / Round Judges | Judge master, RoundJudgeAssignment, Required flags | Assign/unassign; toggle Required | L/E/O/X; Draft editable; Open+ locked; no Required blocker |
| `admin/criteria.html` | `CriteriaConfigurationScreen` / Round Criteria | Versioned criterion/group hierarchy, effective weight | Add/edit criteria | L/E/O/X; Draft editable; invalid/under/over 100%; Open+ locked |
| `admin/round-results.html` | `RoundResultsScreen` / Round Results | Provisional calculation or finalized snapshot, eligibility, advancement | Finalize; visibility; select/reset advancement | L/E/O/X; Open unavailable; Closed provisional; tie warning; Finalized/hidden/visible |
| `admin/result-detail.html` | `ResultDetailScreen` / Round Results detail | Snapshot/provisional contestant item, included/excluded Judge breakdown | Expand criterion breakdown | L/E/O/X; no result; Included/Optional/Excused/Removed; Finalized read-only |
| `admin/advancement.html` | `AdvancementSelectionScreen` / Round Results context | Finalized result, target Round/count, selection, reasons | Top-N edit, preview, confirm | L/E/O/X; not Finalized; tie at cutoff; count mismatch; manual reason; confirmed |
| `admin/contestants.html` | `ContestantsMasterScreen` / Global Event | Event Contestant master, assignment summary | Search/filter; add/edit drawer | L/E/O/X; active/inactive; validation; no manage capability |
| `admin/judges.html` | `JudgesMasterScreen` / Global Event | Event Judge master, assignment summary | Search/filter; add/edit drawer | L/E/O/X; active/inactive; validation; no manage capability |
| `admin/live.html` | `LiveOperationsScreen` / Global Live | Current Open Round, Judge monitoring summary | Open selected Round Monitoring | L/E/O/X; no Round open; stale connection; exception attention |
| `admin/results.html` | `GlobalResultsScreen` / Global Results | Per-Round result status/snapshot summaries | Open Round Results | L/E/O/X; Draft/Open unavailable; Closed provisional; Finalized |
| `admin/audit.html` | `AuditLogScreen` / Global More | Server audit timeline filtered by scope | Filter/query; inspect record | L/E/O/X; permission denied; immutable/read-only; pagination |
| `admin/design-system.html` | `DesignSystemGallery` / developer-only, **not production navigation** | Semantic tokens/component states | Review visual references | Static reference; omit route in release build |
| No HTML; Round tab placeholder | `RoundSettingsScreen` / Round Settings | Round-level settings/policies (scope TBD) | TBD after decision | Placeholder; unavailable/disabled until scope and capability approved |

Global Admin sidebar/bottom navigation is not a replacement for Round tabs. Submission Detail, Result Detail, and Advancement retain the Round Workspace context and appropriate parent tab.

## Judge screens (8 including conceptual Login/Device Session)

| Prototype | Flutter target / nav level | Primary data | Actions | Critical states |
|---|---|---|---|---|
| `index.html` + `mode.html` (mock UX only) | `LoginScreen` → `SessionResolution` → `ModeSelectorScreen` | Authenticated User, event-scoped capabilities, JudgeProfile link, DeviceSession | Authenticate, resolve capabilities, choose mode, log out | L/X; unauthenticated/expired/revoked; offline re-entry policy TBD |
| `pages/my-rounds.html` | `MyRoundsScreen` / Judge root | Assigned Rounds, own submission, result visibility | Enter Open; view own submission/result | L/E/O/X; Draft unavailable; Open ready/in-progress; Closed; Finalized hidden/visible |
| `pages/standby.html` | `StandbyScreen` / Assigned Round entry | Event/Round/Judge context, cached bootstrap | Enter roster | L/O/X; unassigned; round not Open; cache missing; offline-ready |
| `pages/contestants.html` | `JudgeContestantsScreen` / Round flow | Round-specific roster, own score completion | Filter/select contestant | L/E/O/X; unscored/draft/scored; Submitted read-only; round locked |
| `pages/scoring.html` | `ScoringScreen` / Round contestant | Versioned rubric, local own ScoreSheet, contestant | Edit score/note; navigate | L/O/X; locally saved/syncing/conflict; missing required; Submitted/Reopened/Closed read-only as policy |
| `pages/review.html` | `ReviewSubmitScreen` / Round flow | Own completion, totals, sync state | Review; request submit with confirmation | L/E/O/X; incomplete; pending sync; server validation; submit pending/failed/acknowledged |
| `pages/submitted.html` | `SubmittedScreen` / Round flow | Server-acknowledged own submission and score sheet | View own scores; back to My Rounds | L/O/X; pending vs confirmed; Reopened; read-only; round Closed/Finalized |
| `pages/results.html` | `JudgeRoundResultsScreen` / Round result | Backend-filtered official rank/contestant/combined score | View only; back | L/E/O/X; `RESULT_NOT_VISIBLE`; not assigned; Finalized+visible; read-only |

### Judge edit/offline/confirmation contract

| Screen | Edit? | Offline capable? | Server confirmation required? |
|---|---|---|---|
| Session | No scores | Limited cached-session policy TBD | Yes, for fresh authentication/revocation check |
| My Rounds / Standby / Contestants | Navigation only | Yes with valid cached assignment/bootstrap; show freshness | Yes for new assignment/status access |
| Scoring | Own Draft/Reopened only | **Yes, durable local save** | Sync acknowledgement before official submission |
| Review | No direct scores; submit intent | Read/review cached sheet; queue intent policy TBD | **Yes** before displaying Submitted |
| Submitted | Read-only | Cached acknowledged sheet | Yes for authoritative status |
| Results | Read-only | Cached result exposure policy TBD; fail closed if permission stale | **Yes** for visibility/access gate |

The prototype's `preview=1` and seeded mock submission are development affordances, not production screen states.
