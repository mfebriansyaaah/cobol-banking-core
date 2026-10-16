# Roll back on SQL_BEGIN re-entry

Status: accepted
Date: 2026-10-16
Phase: Core bridge & C-libraries audit (FASE C).

## Context

`SQL_BEGIN` on an already-open transaction dropped the handle without
rolling back. The connection (shared keep-alive) kept the partial work, so
the new `START TRANSACTION` would implicitly commit it. Unreachable in
practice — a script verified all 17 `SQL_BEGIN` sites reach COMMIT/ROLLBACK
with no early exit, and timed-out pool workers are SIGKILLed (server-side
rollback) — but a single missed close in a future action would have become a
silent partial commit.

## Decision

- `SQL_BEGIN` now rolls back an open transaction first (plus a static,
  PII-free stderr marker), then proceeds as before. Behaviour is unchanged
  when no transaction is open.
- Covered by `tests/test_bridge_txn.sh` (5 checks): a C harness inserts
  inside an unclosed transaction, re-enters BEGIN, and proves the row is
  gone — plus a normal commit round-trip and the empty-close diagnostic.
  Negative control: the harness fails on pre-fix sources with the leaked row
  committed (count 1), proving the hazard was real.

## Consequences

- The transaction API is now total: there is no path that abandons open
  work, whatever future COBOL flows do.
- Shell 609 -> 614, gateway 104 unchanged; full run 718 assertions.
