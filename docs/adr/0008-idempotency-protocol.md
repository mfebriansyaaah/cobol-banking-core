# ADR 0008: Idempotency-key protocol (claim / replay / takeover)

## Status

Accepted.

## Context

Money writes must survive client retries without double-posting, and a
crashed owner must not block its key for longer than a bounded stale
window. Five domains implement this independently (card capture/repay/
reverse, deposit settle, loan disburse/repay, collection pay, wallet
transfer via `pending_transactions`), all mirroring the original
`payment_settle_request` shape. PR-14 will generalize the tables; until
then the convention must stay uniform or retries will diverge per domain.

## Decision

The per-key request row carries `status` (`PENDING`/`DONE`), the bound
amount, the `gl_journal_id`, and `updated_at`. One verb, three outcomes:

1. **Claim.** `SELECT` the row. `NO_DATA` → `INSERT ... 'PENDING'`
   (owner takes it: `WS-IDEM-OWNED = "1"`). `1062` duplicate → `RETRY`
   (re-read; another attempt won it). Any other error fails closed.
2. **Replay.** `DONE` + amount equal (compared `TRIMMED = TRIMMED`)
   → return the stored outcome verbatim (`SUCCESS|...` passthrough, no
   re-post). `DONE` + different amount → `ERROR|IDEMPOTENCY_CONFLICT`.
3. **Takeover.** `PENDING` older than 5 minutes
   (`updated_at < NOW() - INTERVAL 5 MINUTE`) → the owner takes it over
   with a guarded `UPDATE ... WHERE status = 'PENDING'`; a lost race
   reports `*_IN_PROGRESS` instead of double-posting. A fresh `PENDING`
   owned by someone else reports `*_IN_PROGRESS` untouched.

Refusals before posting delete only our own `PENDING` row
(`WS-IDEM-OWNED = "1"`, key present, `status = 'PENDING'` guard —
`DONE` rows are never touched) so the key stays usable instead of
blocking behind the stale window. Claim refusals perform no delete.
In posting splits (ADR-0010) the callee owns both the paragraph and the
flag, so `CLEANUP=1` paths self-clean and the caller reproduces the
exact output mapping.

## Consequences

- Every money action with a client-supplied key behaves identically;
  the race/conservation/idempotency suites prove each domain, and the
  money-path mutants (M2: both idempotency flags neutered) prove the
  suites notice when the guards go missing.
- PR-14 may replace the tables with a generic
  `idempotency_request(scope, key, ...)` store, but it must preserve
  these exact semantics (dual-write/dual-read first; no table dropped
  in that PR).
