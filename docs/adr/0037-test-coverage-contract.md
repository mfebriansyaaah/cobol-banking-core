# Result-code contract test and idempotency-in-progress coverage

Status: accepted
Date: 2026-10-16
Phase: Test quality & coverage audit (FASE A).

## Context

A test-quality audit found that some documented behaviours had no test at all.
In particular `TRANSFER_IN_PROGRESS` (a same-key transfer already in flight) and
`DB_BUSY` (transient DB failure) were claimed in `docs/STATUS.md` but referenced
by zero tests, and 32 of the 84 codes in `middleware/src/result.js` were never
asserted — so a regression in the COBOL-result → HTTP-status mapping could ship
green.

## Decision

- **Full HTTP contract test**: `middleware/test/result.test.js` now carries an
  explicit table of every error code and its expected status, asserts
  `toHttp('ERROR|<code>')` for each, and asserts that the table and the
  (now exported) `ERROR_STATUS` map list **exactly the same codes**. A new code
  without a documented status fails the test instead of silently defaulting to
  500. An unknown code is separately asserted to fall back to 500.
- **Idempotency in flight**: a gateway test seeds a `PENDING` intent for the
  authenticated sender's key, proves the same-key transfer is refused with
  `TRANSFER_IN_PROGRESS` (409), then flips it to `COMMITTED` and proves the same
  key replays with 200 — matching the documented "concurrent same-key →
  in-progress → replay on retry" behaviour.

## Consequences

- The COBOL→HTTP status contract is locked down; adding or changing a code is
  a deliberate, tested edit.
- `TRANSFER_IN_PROGRESS` and replay are now covered behaviourally.
- Remaining deliberate gap: the COBOL transient detector that produces
  `DB_BUSY` (lock-wait/deadlock/lost-connection) and the legacy
  `CURRENCY_MISMATCH` code (no current producer) are covered at the mapping
  level only, not end-to-end — the transient path cannot be triggered
  deterministically without database-admin rights.
