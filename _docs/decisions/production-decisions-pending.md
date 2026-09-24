# Production Decisions Pending — KREEN Judging

**All items below are open.** The HTML prototype's behavior is an interaction baseline, not approval of production policy. Product/operations, judging authority, security, and backend owners should record a decision, rationale, approver, date, and affected contract before implementation. Do not infer a decision from mock data or a disabled button.

| ID | Decision required | Prototype baseline / uncertainty | Impact if unresolved |
|---|---|---|---|
| PD-01 | May Optional Judges contribute to official results? | **No** in prototype; only assigned Required Submitted/Resubmitted count. | Result formula, eligibility, audit, retrospective corrections. |
| PD-02 | What aggregation formulas are supported? | Arithmetic mean of eligible per-Judge contestant totals; 2-decimal display. | Backend result engine, reproducibility, testing. |
| PD-03 | How are ties resolved for official winner/rank? | Shared rank; no automatic tie-break; acknowledgement before finalize. | Awards, fairness, result contract. |
| PD-04 | Is manual advancement override permitted in production, and by whom? | Super Admin demo may override Top N with reason. | Capability model, governance, audit. |
| PD-05 | Is reason sufficient, or is second approval required for override/finalization/reset? | Single-admin confirmation in prototype. | Dual-control workflow, API commands, audit. |
| PD-06 | How is withdrawal represented and who approves replacement? | Reasoned Draft target adjustment; no formal Withdrawal entity. | Domain model, eligibility, notifications. |
| PD-07 | Can the target count change after source Finalized? | Fixed `advancementCount` on source Round. | Snapshot/advancement versioning and cutoff fairness. |
| PD-08 | At a tied advancement cutoff, advance everyone, choose manually, or use approved rule? | Manual selection with reason; official rank remains tied. | Target capacity, UX, policy transparency. |
| PD-09 | Is score carry-forward or cross-round weighting ever used? | `carryForwardScores = false`; rounds independent. | Result model, API, scoring disclosures. |
| PD-10 | Can progression branch or contestants skip rounds? | Simple next Round by order; no branches/skips. | Advancement graph, assignments, route UX. |
| PD-11 | Can submission be reopened after Round Closed/Finalized? | No ordinary reopen after Closed. | Result invalidation/correction, audit. |
| PD-12 | May an Excused Judge be restored after scoring activity or Round Close? | Restore only while Open; prior Required flag retained. | Eligibility, close guards, score history. |
| PD-13 | How are finalized result corrections/versioning performed? | Snapshot immutable; no correction UI. | Legal/operational traceability, superseding snapshots. |
| PD-14 | Is manual rank override allowed? | No; advancement override does not alter official rank. | Result integrity, approval policy. |
| PD-15 | Can advancement reset after target Round Opens? | No ordinary reset after Open. | Target score invalidation and participant notice. |
| PD-16 | Who may Close when not all assigned Judges submit? | Required active must submit; Optional/Excused do not block. | Close policy and exception authority. |
| PD-17 | Who may view all score sheets vs status-only monitoring? | Super Admin demo sees detail; other roles not enforced. | Privacy, capability grants, API data minimization. |
| PD-18 | Head Judge scope and Event Admin default grants? | Capability matrix has `P` values awaiting policy. | Session/bootstrap capabilities and UI routes. |
| PD-19 | How long may cached assignment authorize offline scoring? | Offline-first target, but lease/revocation behavior undefined. | Safety under revoked device, closed Round, stale rubric. |
| PD-20 | Auth provider, device pairing, session lifetime, remote wipe? | No real auth/device management in prototype. | Security architecture and P1 implementation. |
| PD-21 | Can Judges read cached official Results offline after visibility is turned OFF? | Prototype checks local state; production must fail closed unless approved policy says otherwise. | Result confidentiality, cache TTL/purge. |
| PD-22 | Conflict resolution for concurrent devices or rubric changes? | Prototype has no concurrent sync. | Data loss prevention, offline scoring contract. |

## Resolution gate

Before coding P1–P9, classify each item as **decided**, **explicitly deferred with safe default**, or **blocking**. Result/advancement policy items PD-01–PD-15 must be approved before official calculation and progression implementation. Security/offline items PD-19–PD-22 must be resolved before real Judge scoring with live data. Record resulting API/schema/test changes in a separate reviewed design; this register itself is not approval.
