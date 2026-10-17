# Idempotent development seeds

Status: accepted
Date: 2026-10-17
Phase: Database schema & migrations audit (FASE C).

## Context

`database/seed_test_data.sql` used plain `INSERT`s (except currencies and
rates): re-running it failed on duplicate keys — and would have duplicated
the ledger seed rows, which have no unique key to ignore on. The README
setup flow therefore worked exactly once per database.

## Decision

- User, account, currency and rate fixtures use `INSERT IGNORE` (present
  rows are kept, missing ones restored).
- The two ledger seed rows are reset by key (`DELETE ... WHERE txn_ref IN
  (...)` then re-insert), the only deduplication handle available, keeping
  the seeded balances deterministic.
- Covered by `tests/test_seed.sh` (6 checks): double application succeeds,
  fixture counts are exact, and the sender balance is unchanged. The file
  header documents the keep-vs-reset semantics and the dev-only scope.

## Consequences

- The setup flow is repeatable end to end (schema, seeds, migrations) on an
  empty database and safe to re-run on a dev database.
- Shell 619 -> 625, gateway 104 unchanged; full run 729 assertions.
