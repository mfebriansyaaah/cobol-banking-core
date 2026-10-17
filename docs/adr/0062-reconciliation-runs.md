# Recorded reconciliation with exception workflow (Gate 1)

Status: accepted
Date: 2026-10-17
Phase: Gate 1 — accounting foundation (partial).

## Context

`PRD_Enterprise.md` section 4.B requires operator-controlled and
scheduled reconciliation with immutable results, exception ownership,
resolution workflow, and exportable evidence. `RECONCILE` was a
read-only diagnostic: no history, no owners, nothing scheduled, nothing
exportable.

## Decision

- `reconciliation_runs` (migration 0032): one row per completed run —
  trigger (`MANUAL`/`SCHEDULED`), actor, status, mismatch count. The core
  computes first and inserts final, and a trigger refuses `UPDATE`, so
  results are append-only by construction.
- `reconciliation_findings`: one row per mismatched account per run, with
  a COBOL-enforced lifecycle `OPEN -> ACKNOWLEDGED -> RESOLVED` (direct
  resolve is refused). Resolved rows keep their run link; every transition
  is audited (`RECONCILE_ACK`/`RECONCILE_RESOLVE`).
- New actions: `RUN_RECONCILIATION`, `LIST_RECONCILIATIONS`,
  `LIST_EXCEPTIONS` (optional status filter), `ACK_EXCEPTION`,
  `RESOLVE_EXCEPTION`. All privileged actions are SUPER_ADMIN-only.
- Scheduling is operator-owned: `scripts/scheduled_reconcile.sh` records
  one `SCHEDULED` run per invocation (cron installs it with a provisioned
  `RECON_ACTOR` service identity); `scripts/export_reconciliation.sh`
  prints a run and its findings as CSV evidence.
- Gateway: `POST /admin/reconcile/run` (step-up), `GET
  /admin/reconcile/runs`, `GET /admin/reconcile/exceptions`, `POST
  /admin/reconcile/acknowledge`, `POST /admin/reconcile/resolve`
  (step-up). The read-only `GET /admin/reconcile` diagnostic is unchanged.
- Deliberately out of scope: automatic divergence alerting (runs record;
  nothing pages yet), scheduled *exception* review (PR for the ops
  on-call), and journal↔ledger cross-checks in the scan (structural
  journal checks live in `tests/test_journal.sh`).

## Consequences

- B-P1-RECON is satisfied in code (owner approval outstanding on every
  row). B-P0-BALANCE stays partial: divergence is recorded per run but
  nothing alerts on it.
- `tests/test_reconciliation_runs.sh` (28 checks) uses relative counts so
  shared-database residue cannot flake it.
