# Cross-currency transfers via stored exchange rates

Status: accepted
Date: 2026-10-13
Phase: roadmap item - FX between currencies.

## Context

`TRANSFER` moved money only when both accounts shared a currency; otherwise it
returned `ERROR|CURRENCY_MISMATCH`. Accounts already carry a currency, and the
`currencies` table carries each currency's precision, so the missing piece was
a rate source.

## Decision

- `exchange_rates` (base -> target, `DECIMAL(18,6)`) is the rate source
  (migration 0008; re-introduced after the 0007 cleanup).
- `TRANSFER` resolves the sender and target accounts, then:
  - same currency: credited = amount (rate 1);
  - different currency: look up the rate for
    `base = sender currency, target = target currency`. If none exists, the
    transfer fails with `ERROR|RATE_NOT_FOUND` and nothing moves.
- The sender is debited by `amount`; the target is credited by
  `ROUND(amount * rate, 2)`. The conversion and rounding happen in SQL so the
  decimal semantics are MySQL's, not the COBOL `DECIMAL-POINT IS COMMA` layer's.
- The ledger keeps the audit trail: `DEBIT` in the sender's currency and
  `CREDIT` in the target's currency (same `txn_ref`), so the moved amounts are
  both recorded.

## Consequences

- Cross-currency transfers are supported; the rate is plain data (no rounding
  rule per currency beyond 2 decimals, matching `accounts.balance`).
- The credited amount is derived at execution time; an idempotent replay returns
  the original success without recomputing (the committed ledger holds it).
- FX direction matters: only `base -> target` rates are looked up; a missing
  pair is a clear `RATE_NOT_FOUND` rather than a silent wrong amount.
- The rate snapshot is not stored on the transaction beyond the resulting
  credited amount; recording the rate itself is a future refinement.
