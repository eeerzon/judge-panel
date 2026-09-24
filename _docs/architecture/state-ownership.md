# State Ownership — KREEN Judging

## Core Rule

```text
Backend          = authoritative data
Flutter Local DB = offline working copy
UI State         = derived/presentation state
```

No UI screen may become the durable source of a business fact merely because it can render or cache it.

## Ownership Matrix

| Data/state | Authoritative owner | Local/offline role | UI role |
|---|---|---|---|
| Event, branding, timezone | Backend | Cached configuration | Render selected event context |
| Round configuration/status | Backend | Cached read model | Render permitted actions |
| Contestant/Judge master | Backend | Cached read model | Display/search/select |
| Round participation/assignment | Backend | Cached read model | Filter My Rounds and admin lists |
| Criteria/rubric | Backend | Versioned/cached for offline scoring | Render scoring controls and validate locally |
| Score draft | Backend after sync | Durable local working copy + pending mutations | Render/edit only when lifecycle permits |
| ScoreSheet submission status | Backend | Cache last acknowledgement and pending submit command | Display locked/pending/retry state |
| Result/ranking | Backend | Cached official result only | Render only after server grants visibility |
| Permission/capability | Backend/session claim | Cached only for UX; must refresh/deny safely | Hide/disable non-permitted actions but never enforce alone |
| Audit log | Backend | Optional read cache | Render permitted records |
| Connection/sync state | Client sync layer plus backend acknowledgement | Durable queue metadata as appropriate | Render operational status |

## Derived State Rules

### Contestant status

`Not Scored`, `Draft`, and `Scored` are derived from required Score records for the active ScoreSheet and active Round rubric. They must not be an independently mutable persistent field.

### Personal total score

Derived from the active Round criteria and the Judge's own Score records. A missing required score must not become zero or a partial official total unless business rules explicitly introduce such a mode.

### Round progress

Derived from authoritative assignment + score sheet/submission data. Local UI can calculate a provisional display while offline, but operational admin status must indicate its freshness/sync state.

## Mutation and Sync Rules

- Score input writes first to a durable local working copy; sync is queued when connectivity permits.
- Submit must be idempotent. Repeating a request after ambiguous network failure cannot create multiple official submissions.
- A local “submitted” display that lacks backend confirmation must be represented as pending/retrying, not final lock.
- The backend must reject writes prohibited by Round/ScoreSheet state even if an outdated client UI still exposes them.
- Reopen is an authoritative backend command requiring capability, reason, and audit log; local UI reflects the confirmed result.

## Prototype Boundary

Current `state.js` correctly centralizes prototype formulas and status derivation, but its `localStorage` blob is not production ownership. It remains unchanged in Phase 0.
