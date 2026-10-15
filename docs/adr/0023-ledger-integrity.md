# Ledger durability and immutability

Status: accepted
Date: 2026-10-15
Phase: Ledger/Transactions hardening (FASE B).

## Context

The PRD requires an "immutable ledger", but:

- `ledger.account_id` was `ON DELETE CASCADE`, so deleting an account (or a user,
  which cascades to accounts) **destroyed** its ledger history.
- Nothing at the database level prevented `UPDATE`/`DELETE` on `ledger`; the
  "immutability" was only an application convention.

## Decision

- **Append-only**: a `BEFORE UPDATE ON ledger` trigger refuses any update
  (`SIGNAL SQLSTATE '45000'`). Nothing in the core ever updates a ledger row.
- **Preserve on deletion**: a `BEFORE DELETE ON accounts` trigger copies the
  account's ledger rows into `ledger_archive` (no foreign key) before the FK
  cascade removes them, mirroring the audit-trail trigger. Deleting a user
  cascades to accounts, so the same path preserves ledger rows.
- **Defensive constraint**: `CHECK (amount >= 0)` on `ledger` (a zero row is
  allowed because the seed/`GET` fixtures create one; negatives are refused).

## Consequences

- Ledger rows are never modified in place, and account/user deletion no longer
  destroys history — the durable copy is in `ledger_archive`.
- `UPDATE ledger` (e.g. tampering) fails loudly; direct `DELETE FROM ledger`
  is still allowed (tests and the cascade use it), so the archive trigger is the
  durability guarantee rather than a hard delete block.
- A `UNIQUE (txn_ref, account_id, type)` posting constraint was considered and
  **rejected**: a reversal posts compensating rows under the same reference, so
  the tuple legitimately repeats across same-reference transfers.
- Covered by `tests/test_ledger_integrity.sh`.
