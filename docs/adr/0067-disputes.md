# Customer disputes and complaints (Gate 2)

Status: accepted
Date: 2026-10-17
Phase: Gate 2 — production controls (partial).

## Context

`PRD_Enterprise.md` section 4.E requires a customer ticket lifecycle linked
to accounts/transactions, controlled assignments, response deadlines,
escalation, and immutable case history. There was no ticketing at all.

## Decision

- New tables (migration 0036): `dispute_cases` (`OPEN` → `ACKNOWLEDGED` →
  `RESOLVED`, with `REJECTED` from `OPEN`/`ACKNOWLEDGED`) and
  `dispute_messages` (append-only; `UPDATE` refused by trigger, the
  ledger/audit mechanism; `DELETE` allowed so user/case cascades work;
  no COBOL path updates or deletes).
- New `wallet_core` actions: `OPEN_DISPUTE` (owner-only; optional
  `txn_ref` must be the owner's own pending or posted transaction),
  `ADD_DISPUTE_NOTE` (owner or `SUPER_ADMIN`, only on open cases),
  `ACK_DISPUTE` / `RESOLVE_DISPUTE` / `REJECT_DISPUTE` (`SUPER_ADMIN`
  only, strict ordering: only `OPEN` can be acknowledged, only
  `ACKNOWLEDGED` resolved; every transition audited),
  `LIST_DISPUTES` (non-admins pinned to their own cases) and
  `GET_DISPUTE` (case plus messages, oldest first).
- No hardcoded SLA: the due date is set by the acknowledging admin
  (human policy, may be empty); the list and detail views compute an
  overdue flag (`due_date` past and still open) instead of automatic
  escalation.
- Gateway: `POST /disputes`, `POST /disputes/:id/notes`,
  `POST /disputes/:id/acknowledge|resolve|reject` (step-up),
  `GET /disputes` (optional `email`/`status`/`limit`/`offset`),
  `GET /disputes/:id`, with parsed case/note views.
- Deliberately out of scope: SLA/escalation policy and deadlines,
  customer close/reopen, attachments, e-delivery of outcomes, retention.

## Consequences

- E-P1-DISPUTES is satisfied in code (owner approval outstanding on the
  traceability row). `tests/test_disputes.sh` (39 checks) plus a gateway
  end-to-end test cover the lifecycle, assignment, deadlines, overdue
  flags, visibility, and history immutability.
- No money moves through disputes; notes never alter case state.
