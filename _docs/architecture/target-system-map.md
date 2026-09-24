# Target System Map — KREEN Judging

## Status

Target production concept only. Tidak ada Flutter, backend, API, database, atau integrasi yang dibangun dalam Phase 0.

## Product Map

```text
KREEN JUDGING APP
│
├── Judge Mode
│   ├── Login / Device Session
│   ├── My Rounds
│   ├── Standby (round-specific)
│   ├── Contestants
│   ├── Scoring
│   ├── Review & Submit
│   ├── Submitted / read-only score sheet
│   └── Round Results (only when fairness gate permits)
│
└── Admin Mode
    ├── Event Overview
    ├── Rounds
    │   └── Round Detail: Overview / Contestants / Judges / Criteria /
    │       Monitoring / Results / Settings
    ├── Contestants Master
    ├── Judges Master
    ├── Live Monitoring
    ├── Results
    ├── Settings
    ├── Audit Log
    └── Device / Session Management
```

Judge Mode memakai shell immersive tanpa sidebar agar fokus scoring tetap sama dengan prototype. Admin Mode memakai workspace/sidebar, namun tetap dalam visual language burgundy-gold yang sama dan bukan generic SaaS dashboard.

## System Boundary Map

```text
Flutter Judge/Admin Clients
├── Presentation/UI state (derived only)
├── Domain/application rules
├── Local persistent database (offline working copy)
└── Sync queue / idempotent commands
                 │
                 ▼
KREEN Backend (authoritative)
├── Auth, roles, and scoped capability checks
├── Event / round / assignment configuration
├── Authoritative score sheet and submission state
├── Result calculation and fairness gates
├── Audit log
└── Device/session management
```

## Responsibilities

| Layer | Responsible for | Must not be treated as |
|---|---|---|
| Judge/Admin UI | Render permission-filtered information, collect intent, communicate state. | Authoritative source of score/result/permission truth. |
| Flutter local DB | Durable offline work, cached configuration, pending commands, last confirmed data. | Substitute backend or permanent conflict resolver. |
| Sync layer | Retry, idempotency, ordering/conflict protocol, sync status. | UI-only decorative connection status. |
| Backend | Authorization, source of truth, lifecycle enforcement, official submission/result/audit records. | Optional mirror of local client data. |

## Existing Prototype Mapping

| Existing prototype concept | Target system concept |
|---|---|
| `mock-data.js` Event/Judge/Round | Backend configuration + local cached working data |
| `state.js` score/status formula | Domain rules, tested on client and enforced by backend where authoritative |
| browser `localStorage` | Flutter local persistent database; no longer canonical |
| `isSubmitted` boolean | Server-confirmed ScoreSheet/Submission lifecycle |
| dev connection panel | Real connectivity + sync queue state, with a separately gated developer test tool |
| five HTML pages | Judge Mode UX reference, not production code |

## Non-Goals

- Selecting Flutter state-management, database, authentication provider, or transport.
- Designing API endpoint syntax.
- Defining database schema.
- Implementing any part of the map in Phase 0.
