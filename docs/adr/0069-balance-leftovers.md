# Balance leftovers: dashboard availability and divergence alerting

Status: accepted
Date: 2026-10-17
Phase: Gate 1 — accounting foundation (closing unblocked gaps).

## Context

`B-P0-BALANCE` required an authoritative balance with transactional
projection updates, recomputation, reconciliation, and alerting on
divergence. Two gaps needed no owner decisions: the dashboard showed
raw balances at fixed 2dp with no spendable figure, and a recorded
divergence produced no signal.

## Decision

- `GET_DASHBOARD` now projects each account as
  `iso:balance:available:status` with the currency's own precision —
  the same expression as `CHECK_BALANCE`, so holds reduce the spendable
  figure on the dashboard too. This also fixes IDR-style zero-precision
  currencies, which previously rendered as `0.00`.
- `scripts/scheduled_reconcile.sh` exits 2 with a structured
  `ALERT|DIVERGENCE` line on any recorded mismatch (exit 1 stays
  reserved for a failed run). Any mismatch alerts — no threshold to
  approve, since a single unbalanced cent is already a SEV-grade event.
  The alert-response runbook names this signal.
- `tests/test_reconciliation_runs.sh` gains alert checks (exit code,
  alert line, fixing fixtures drops the count by exactly the fixed
  accounts); the gateway profile test asserts the available/status
  fields.

## Consequences

- B-P0-BALANCE is satisfied in code (owner approval outstanding on the
  traceability row). The dashboard and the balance endpoint can no
  longer disagree about spendable money.
- The alert fires when the scheduled run executes; installing the
  schedule itself remains an operator step (deploy runbook).
