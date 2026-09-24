# Local Storage and State Ownership — Production Concept

No Flutter database package or physical schema is selected here. Choose after platform, encryption, migration, performance, and test review. `localStorage` is a prototype mechanism only. The Judge client needs a **transactional, durable** local store; Admin may use a lighter read cache but must never present an offline command as authoritative.

## State categories

- **A. Server authoritative:** Event, Round and lifecycle, masters, assignments, rubric version, submitted ScoreSheet, reopen, result snapshot, visibility, advancement, capabilities, device/session, audit.
- **B. Local persistent:** cached authorized bootstrap, Judge draft score/note, pending mutation queue, idempotency key, last acknowledged versions, sync cursor/metadata. Survives process death.
- **C. UI transient:** selected tab, search/filter, open drawer/dialog, unconfirmed advancement selection, focused score input. May disappear on restart without losing business data.
- **D. Derived:** completeness, personal total, required-submission readiness, effective scored weight, button eligibility, local sync status. Recompute from versioned inputs; do not store as independent mutable truth.

## Ownership matrix

| State | Owner | Client persistence | Offline behavior | Conflict strategy |
|---|---|---|---|---|
| Event and branding | Backend | Read cache | Show cached context with freshness | Refresh by server version; no client edit offline |
| Round/status/order | Backend | Read cache | Existing cached Round view; transitions unavailable | Server lifecycle wins; invalidate stale client actions |
| Contestant/Judge master | Backend | Read cache scoped to Event | Cached roster/identity only as permitted | Server revision wins; rebase unsent references by stable ID |
| RoundContestant | Backend | Versioned bootstrap cache | Judge sees cached authorized roster | Reject stale roster; pause sync if removed contestant affects draft |
| RoundJudgeAssignment / Excused / Removed | Backend | Versioned bootstrap cache | Show last known access with stale warning; no new authority | Server permission/exception wins; stop writes on revocation |
| Criteria/rubric | Backend | Versioned, pinned in ScoreSheet bootstrap | Score only against cached approved version | Block/resolve version mismatch; never silently remap scores |
| ScoreSheet state/version | Backend after acknowledgement | Own sheet snapshot + local working revision | Draft remains usable if cached/assigned | Optimistic version check, 409 fetch/resolve |
| Individual Score and note draft | Local device until accepted; then Backend | **Durable transactional write per edit** | Full own draft editing when authorized cache exists | Ordered queue; per-field merge only under approved policy, otherwise user-visible conflict |
| Submission | Backend | Ack cache + durable pending submit command/key | Pending is not Submitted; retry safely | Idempotency key, version check, server acknowledgement |
| Reopen/history | Backend | Read cache | Read only; cannot self-reopen | Server outcome; rebootstrap sheet before editing |
| Result snapshot | Backend | Optional permission-filtered read cache | Judge cached visibility policy TBD; fail closed if uncertain | Immutable snapshot ID/version; no client recalculation |
| Result visibility | Backend | Short-lived read cache only | Do not assume old ON permission remains valid | Server gate on every result query; revoke cache on denied access |
| Advancement/target assignments | Backend | Admin read cache | Preview locally; no offline confirmation in baseline | Optimistic target/source versions; reject stale confirmation |
| Audit | Backend append-only | Optional read cache | Label cached/stale; no client-generated official events | Server append-only order/cursor |
| Capability/session/device | Backend/auth service | Secure, short-lived session material as approved | Offline scoring policy limited to pre-authorized cache | Revoke/expire stops sync and protected reads; no role inference |
| Sync queue/cursors | Client sync layer + server acks | Durable local store | Retry later; never drop unacknowledged score | Stable mutation ID/order, dedupe, version checks |

## Conceptual local collections

`cached_events`, `cached_rounds`, `round_roster`, `round_criteria_versions`, `own_score_sheets`, `draft_scores`, `draft_notes`, `pending_mutations`, `pending_submissions`, `sync_cursors`, `last_sync_metadata`, and `session_scope`. Names are illustrative, **not** a database schema. Admin may cache summaries and edit drafts, but sensitive commands still require server acknowledgement. Partition by account/Event/Judge; prevent one session from reading another's cache.

## Judge durability transaction

On score edit: validate against the pinned criterion → commit new local value, local revision/timestamp, and queue item **in one durable transaction** → only then show “Saved locally” → sync asynchronously. If the transaction fails, keep the editor open, show “Unable to save,” and do not imply persistence. On restart, load the exact draft and unsent queue before allowing further scoring. Use stable identifiers (`roundId`, `scoreSheetId`, `contestantId`, `criterionId`), never list positions.

Keep server-acknowledged state and local pending state separate. `Submitted`, `Finalized`, visibility, and capability are never promoted locally from a button press. Define encryption-at-rest, retention/remote wipe, backup exclusion, and privacy behavior during the production security review; no secrets or private Judge breakdown should be kept in broad logs.
