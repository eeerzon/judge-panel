# Sync Strategy — Judge Offline-First, Server Authoritative

This defines protocol **semantics**, not an HTTP/library implementation. Server must specify exact payloads, retry limits, versioning, and retention before coding.

## Flow

```text
Authenticate + capability check
  → bootstrap assigned Round/roster/versioned rubric/own ScoreSheet
  → transactionally cache bootstrap
  → edit score; durable local write + ordered queue
  → incremental sync; receive per-mutation acknowledgement and server version
  → resolve any conflict
  → validate complete/fully accepted sheet
  → idempotent submit command
  → server acknowledgement → Submitted/read-only
```

Bootstrap must include Event/Round IDs, assignment and access, contestant roster, rubric version, ScoreSheet ID/version, own accepted scores, submission state, capabilities and expiry/freshness metadata. An offline Judge may continue a previously cached, authorized Open round under an approved lease policy; the backend can still reject late writes if Round closes or assignment is revoked. UI must not promise eventual acceptance.

## Score mutation and acknowledgement

Conceptual score mutation: `scoreSheetId`, `roundId`, `contestantId`, `criterionId`, `value`, `updatedAtLocal`, `clientMutationId`, `baseScoreSheetVersion`. Conceptual response: `accepted`, `serverVersion`, `updatedAtServer`, normalized validation/errors. Local timestamps aid diagnostics but never outrank server versions. Backend validates criterion range/step/rubric revision and recalculates criterion/contestant/weighted totals; it does **not** trust client totals.

Queue mutations in a deterministic per-ScoreSheet order. Coalesce superseded unsent edits to the same score only if doing so preserves intent and recovery; never erase the last durable value before acknowledgement. Retry transient failure with backoff/jitter. Persist queue and idempotency IDs across restart. An acknowledgement clears only the matching pending mutation and records the returned server version. Incremental sync fetches assignment, lifecycle, rubric, score, and submission changes since the last acknowledged cursor; cache writes are transactional.

## Submission idempotency

Candidate command: `POST /api/v1/score-sheets/{id}/submit` with stable `idempotencyKey` and expected `scoreSheetVersion`. The same logical attempt reuses the **same** key through timeouts/retries. Server returns the original acknowledgement for duplicates, not a second submission event. Only a **new** authorized submit after a recorded Reopen uses a new key. Before submit, flush/ack all score edits and let server validate required completeness; if offline, show pending intent or block per policy—never label it Submitted. Ambiguous network outcome triggers status lookup/retry with the same key.

## Version and conflict handling

Use optimistic concurrency, e.g. `scoreSheetVersion`/rubric revision. On `409 VERSION_CONFLICT` or a lifecycle/assignment change: stop destructive overwrite and submit, retain the local draft and queue, fetch authoritative latest state, show a clear conflict with affected fields and recovery options, and only resume after an approved rebase or authorized resolution. Never silently drop a newer server value or auto-merge changed rubric semantics. A closed round/revoked assignment yields a locked state plus recoverable local draft export/support path according to security policy, not an unauthorized upload.

## Failure and UI states

| Sync condition | UI promise | Allowed action |
|---|---|---|
| Local transaction complete, network unavailable | “Saved locally · waiting to sync” | Continue own draft if cached access permits |
| Queue sending | “Syncing” | Continue editing with ordered queue; no official submit yet |
| All edits acknowledged | “Synced” + server time/version | Submit if complete and Round Open |
| Validation error | “Fix highlighted score” | Correct draft; no auto-rounding or silent zero |
| Version conflict | “Conflict — review required” | No overwrite/submit until resolved |
| Submit sent, no response | “Submission pending verification” | Retry/status check with same idempotency key |
| Submit acknowledged | “Submitted” and read-only | View own sheet; Reopen only by authorized Admin |
| Device/session revoked | “Access expired” | Stop protected requests; preserve/dispose local draft per approved policy |

## Test obligations

Kill/restart after local edit, while queued, during submit timeout, and after server ack but before local ack write. Exercise duplicated submit, intermittent network, out-of-order acks, stale rubric, conflicting second device, Round close during offline work, assignment Excused/Removed, device revocation, and clock skew. Audit source is the server, not queue logs. Eventual consistency and offline lease durations are production decisions, not inferred from the prototype's `file://` behavior.
