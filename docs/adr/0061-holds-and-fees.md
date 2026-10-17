# Holds, available balance, and scheduled fees (Gate 1)

Status: accepted
Date: 2026-10-17
Phase: Gate 1 — product lifecycle (partial).

## Context

`PRD_Enterprise.md` section 4.B requires holds/releases and fees as
explicit state transitions, with amounts and policy approved by the
accountable owner (Gate 0). No owner exists yet, so this change delivers
the mechanism with no live policy: an empty fee schedule charges nothing,
and holds exist only when an admin places them. Pricing and hold policy
stay owner decisions recorded in data, never in code.

## Decision

- `account_holds` (migration 0031): `PLACED` rows reduce the spendable
  balance (`balance - live holds`); `RELEASED`/`EXPIRED` rows are history.
  Expiry is lazy (every transfer expires what it meets) plus explicit
  release. Placement locks the account row first, so concurrent transfers
  cannot over-commit; a hold beyond the balance fails closed.
- New COBOL actions `PLACE_HOLD`/`RELEASE_HOLD` (SUPER_ADMIN only,
  step-up over HTTP, audited with actor attribution). Amounts obey the
  currency precision; malformed settings fail closed.
- `TRANSFER` checks the available balance, not the ledger balance, and
  `CHECK_BALANCE`/`GET /wallet/balance` report `iso:balance:available:status`.
  `GET /profile` still shows ledger balances only (follow-up).
- `fee_schedule` (migration 0031): bank-owned per-currency flat fee in
  major units; no row means no fee. A configured fee posts as its own
  `FEE` journal (DEBIT sender, CREDIT fee-income account) inside the same
  transaction, verified by the same balanced-leg check. A missing income
  account or an unrepresentable fee fails the whole transfer closed.
- Gateway: `POST /admin/holds`, `POST /admin/holds/release` (both
  step-up), and the `available` field on balances.
- Deliberately out of scope: approved fee amounts and hold policy (Gate 0
  owners), fee tiers/percentages, end-of-day value dating, dashboard
  available display, and scheduled (operator-cron) reconciliation of holds.

## Consequences

- `tests/test_holds.sh` (32 checks) covers the lifecycle, enforcement,
  expiry, fees, and a scoped reconciliation (no over-held account; suite
  accounts absent from `RECONCILE` mismatches).
- B-P1-LIFECYCLE stays partial: transfers and compensating reversals are
  journal-headed with fees and holds enforced, but funding/withdrawal,
  end-of-day, and approved pricing are still missing.
