# API Boundary — KREEN Judging

## Purpose

Dokumen ini menetapkan boundary responsibility untuk API masa depan tanpa mendesain endpoint atau payload final. API belum dibangun dalam Phase 0.

## Backend Must Authoritatively Enforce

1. Authentication/session validity and device/session policy.
2. Scoped capability authorization for Event and Round.
3. Round lifecycle transitions and required preconditions.
4. ScoreSheet lifecycle, including submit lock and reopen.
5. Score validation against the active, versioned Round rubric.
6. Idempotent submission semantics.
7. Fairness/visibility gates for scores, results, and ranking.
8. Result calculation, finalization, and audit recording.

UI hiding, disabled buttons, or cached role data are never sufficient enforcement.

## Command Boundaries

The following represent intent-level commands, not endpoint proposals:

```text
manage event / round configuration
assign contestant to round
assign judge to round
open round
close round
save score draft
submit score sheet (idempotent)
reopen submission (requires reason)
finalize round results
change results visibility
revoke/unlink device session
```

Each sensitive command must produce an auditable authoritative outcome. Commands must be rejected with a machine-readable reason when the actor, lifecycle state, or configuration is invalid.

## Query Boundaries

Queries must be permission-filtered by backend, including:

```text
My Rounds for the active Judge
round roster and rubric for an assigned Judge
own ScoreSheet and own submitted detail
admin operational monitoring
all scores only for actors with view_all_scores
results only after lifecycle + visibility gate passes
audit log only for actors with view_audit_log
```

## Offline Boundary

- Client may create local score draft mutations while offline only for an assigned, locally cached Round/rubric.
- Client cannot independently make official state transitions such as Submitted, Reopened, Closed, or Finalized.
- Sync protocol must preserve idempotency and surface conflicts/failures explicitly.
- API design must identify versioning for rubric/configuration and mutation ordering before production implementation.

## Explicitly Deferred

- HTTP/GraphQL choice.
- Endpoint routes, request/response schemas, error codes, and pagination.
- Authentication mechanism.
- Conflict-resolution algorithm.
- Database design and migration strategy.
