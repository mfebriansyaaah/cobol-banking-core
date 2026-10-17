# Customer statements (Gate 2)

Status: accepted
Date: 2026-10-17
Phase: Gate 2 — production controls (partial).

## Context

`PRD_Enterprise.md` section 4.D requires customer records: transaction
history and statements with opening/closing balances, value/posting dates,
currency, references, fees, and corrections/reversals. The ledger existed
only as raw rows; there was no customer-facing statement.

## Decision

- Read-only `STATEMENT` action in `cobol/src/wallet_core.cob`
  (`p1=owner`, `p2=actor` via `ALLOW-READ`, `p3=currency ISO`,
  `p4="from,to"` ISO posting dates, `p5=limit`, `p6=offset`).
  No new tables: the statement is projected from the immutable ledger,
  so every statement is reproducible from source records by construction.
- Each statement carries opening and closing balances plus one row per
  posting, oldest first: posting date, journal value date, reference,
  journal source, side, amount, running balance after the row (window
  function in SQL), a reversal flag, and the ledger description. Journal
  source distinguishes transfers, fees, and reversals; rows whose
  transaction was reversed are flagged via `transfer_reversals`.
- Rows pre-dating the journal header (legacy seed rows with
  `journal_id IS NULL`) render with source `TRANSFER` and value date
  equal to the posting date rather than being dropped.
- Gateway: `GET /statements` (bearer, owner or admin) with `email`,
  `currency`, optional `range` (`from,to` ISO dates, each side optional),
  `limit`, `offset`; parsed into `{ opening, closing, currency, total,
  lines }`.
- Deliberately out of scope: statement snapshotting/immutability proofs,
  export formats (PDF/CSV/MT940), e-delivery, retention/legal hold, and
  multi-account consolidated statements.

## Consequences

- D-P1-RECORDS is satisfied in code (owner approval outstanding on the
  traceability row). `tests/test_statements.sh` (29 checks) plus a gateway
  end-to-end test cover authorization, balance math, reversal flags, fee
  legs, ranges, and paging.
- Statements never move money: the action performs no writes and takes no
  locks.
