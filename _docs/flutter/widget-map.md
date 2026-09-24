# Flutter Widget / Component Map

This is a semantic reuse map, **not** a package or exact class-design mandate. Widgets receive typed view models and callbacks; they do not directly mutate repositories or make authorization decisions. Component tokens and accessibility are derived from the existing [Judge](../design/design-system.md) and [Admin](../design/admin-design-system.md) references, not copied pixel for pixel.

| Widget | Responsibility | Key inputs | States / reuse scope |
|---|---|---|---|
| `AdminShell` | Global structure and safe-area/content constraint | Event, session, active global destination, content | Desktop/tablet/mobile; all Admin product screens |
| `AdminSidebar` | Persistent global nav | Destinations, capability-filtered access, active item | Expanded/compact/hidden; Admin landscape |
| `AdminBottomNavigation` | Portrait global nav | Primary destinations, active item, More trigger | Safe area, keyboard, selected; Admin portrait/mobile |
| `AdminMoreSheet` | Secondary destinations | Capability-filtered items, session actions | Open/closed, scrollable; Admin portrait/mobile |
| `EventContextHeader` | Selected Event and actor context | Event identity, year, actor, freshness | All Admin screens; compact portrait variant |
| `RoundWorkspaceHeader` | Persistent Round name/status/facts | Round, assigned counts, lifecycle, return action | All Round screens and detail screens; never page-specific shell |
| `RoundTabs` | Secondary Round navigation | Round ID, tabs, active tab, availability | Scroll/adaptive, keyboard/focus; all Round screens |
| `StatusBadge` | Operational status language | Semantic status, label | Draft/Open/Closed/Finalized, score/submission, exception; both modes |
| `StatCard` | Compact key metric | Label, formatted value, supporting text | Loading/stale/normal; Admin overview/round/results |
| `DataRowCard` | Responsive data row/card | Identity, metadata, status, actions | Table landscape/card portrait, empty/locked; Admin lists |
| `EmptyState` | No data/permission/context | Title, explanation, recovery action | All list and detail screens |
| `WarningPanel` | Actionable blocker/exception | Severity, reason, link/action | Readiness, tie, stale data, conflict; both modes |
| `ConfirmationDialog` | Guarded state-changing command | Title, impact text, confirm/cancel, pending state | Open/Close/Finalize/Advance/Reset; Admin and submit Judge |
| `ReasonDialog` | Capture mandatory reason | Prompt, validation, confirm/cancel | Reopen, Excuse, advancement override/reset/adjustment |
| `JudgeCard` | Judge identity + assignment/progress | Judge, required, assignment, submission summary | Assigned/optional/excused/removed; Admin monitoring/config |
| `ContestantCard` | Contestant identity/photo/status | Master identity, number, photo, round status | Portrait fallback, selected/disabled; Admin and Judge |
| `ScoreInput` | Large accessible criterion control | Criterion limits/step, local value, onChange | Empty/valid/invalid/read-only/saving/conflict; Judge scoring |
| `ScoreSummary` | Own contestant total/completeness | Derived total, required missing list | Draft/complete/read-only; Judge scoring/review |
| `SubmissionStatus` | Communicate local vs server state | Local revision, queue, server acknowledgement | Saved locally/syncing/pending/submitted/reopened/conflict |
| `ResultsTable` | Rank/score display | Permission-filtered result rows | Provisional Admin/final Admin/Judge redacted, tie, loading |
| `ResultBreakdown` | Explain included/excluded Judge arithmetic | Authorized breakdown rows, criterion detail | Admin-only, expanded/collapsed, read-only |
| `AdvancementSelectionRow` | Explicit Top-N/override choice | Snapshot item, selected, cutoff tie, onChange | Suggested/manual/disabled, desktop/portrait |
| `AdvancementPreview` | Compare advancing/not advancing before commit | Selected IDs, target, reason, snapshot | Top-N/manual/tie; Admin Round Results context |
| `ReadinessChecklist` | Explain lifecycle blockers | Derived checks, action destinations | Ready/review/locked; Round Overview |
| `AuditTimeline` | Read-only authoritative event trail | Events, filters, cursor | Loading/empty/error/paginated; Admin only |
| `JudgeRoundShell` | Focused Judge presentation/navigation | Event/Round/Judge context, content | Landscape/portrait, offline banner; all Judge round screens |

## Composition contracts

```text
AdminShell
 ├─ AdminSidebar OR AdminBottomNavigation + AdminMoreSheet
 ├─ EventContextHeader
 └─ RoundWorkspaceHeader + RoundTabs + page content (for every Round route)

JudgeRoundShell
 └─ Standby / ContestantCard list / ScoreInput + ScoreSummary / Review / Submitted / Results
```

- One global active destination plus one optional active Round tab. Do not derive one from the other.
- Responsive list/table adaptation lives in reusable primitives; business screens supply data and actions.
- Screens never compute official results. They consume backend result models and permission-filtered payloads.
- Dialogs display backend rejection/error without pretending a command succeeded.
- Critical labels are textual as well as colored; target controls ≥48 dp and support screen readers, keyboard traversal, dynamic text, and reduced motion.
