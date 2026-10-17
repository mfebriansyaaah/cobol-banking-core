# Journal header and pre-commit balance check (Gate 1)

Status: accepted
Date: 2026-10-17
Phase: Gate 1 — accounting foundation.

## Context

`PRD_Enterprise.md` section 4.B requires every posted movement to carry
balanced debit and credit legs in an immutable journal (account, currency,
value date, posting time, source, reference, actor), with reversals as new
compensating entries. The transfer path posted bare legs: no header, no
machine-checked balance between the legs, and audit rows unlinked to any
posting. A crash between the leg inserts was safe only by luck of a single
transaction, with no test proving recovery.

## Decision

- `journal_entries` (migration 0030, folded into `database/schema.sql`):
  one row per posting event — `txn_ref`, `source` (`TRANSFER`/`REVERSAL`),
  `actor_email`, `value_date` (posting date until end-of-day posting
  exists), posting time. `ledger.journal_id` and `audit_trail.journal_id`
  point at it; archives carry the link.
- The COBOL core opens the journal inside the posting transaction, pins it
  through the connection-scoped `@jid` (no new bridge calls, no parameter
  growth), and runs `VERIFY-JOURNAL-BALANCED` before `COMMIT`: exactly one
  DEBIT and one CREDIT leg whose amounts agree through the snapshotted rate
  — in either direction, so transfers and reversals share one check. A
  violation rolls everything back as `DB_ERROR`.
- Every `CREDIT` leg snapshots its rate (reversals snapshot the original
  rate); `value_date` stays the posting date and `prec_val > 4` stays
  refused — rate validity windows and fees remain open gaps.
- `tests/test_journal.sh` (30 checks): header shape per posting, leg/audit
  links, same- and cross-currency agreement, a structural invariant over
  every journal in the database, and a deterministic kill -9 mid-posting
  (blocked on the journal insert by a table lock) proving rollback plus a
  clean retry on the same key.

## Consequences

- B-P0-DOUBLE is satisfied in code (owner approval still outstanding on
  every row); B-P1-LIFECYCLE stays partial (funding, withdrawal, fees,
  holds, end-of-day are still missing).
- `TX_STATUS` still displays two-decimal intent amounts and `RECONCILE`
  still covers balance-vs-ledger only; journal completeness is covered by
  the structural suite until the scheduled-reconciliation work (PR 5).
