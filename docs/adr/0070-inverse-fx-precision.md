# Exact inverse-rate FX conversion

Status: accepted
Date: 2026-10-17
Phase: Gate 1 — accounting foundation (B-P0-PRECISION).

## Context

A cross-currency transfer whose only rate row is the inverse pair (e.g.
IDR→USD when only USD→IDR exists) applies the reciprocal of that rate. The
reciprocal was computed as `ROUND(1 / exchange_rate, 6)` and snapshotted on
the CREDIT ledger leg, whose column was `DECIMAL(18,6)`. Six decimals is not
enough: for USD→IDR = 15700 the reciprocal becomes `0.000064` instead of
`0.000063694268`, so 100000 IDR credits **6.40** USD instead of **6.37**
(a ~0.5% over-credit, always in the customer's favour), and at scale the
error grows (1e11 IDR credits 6400000.00 instead of 6369426.75). The existing
suite masked it: its inverse case used 15700 IDR, where the rounding error
happens to cancel.

## Decision

- Compute the reciprocal with explicit scale —
  `CAST(CAST(1 AS DECIMAL(30,20)) / exchange_rate AS DECIMAL(30,18))` — so it
  carries 18 decimals and the credited amount is exact at the target
  currency's own precision, including at the full `DECIMAL(18,4)` amount
  range. MySQL's implicit division (`div_precision_increment = 4`) is not
  relied on.
- Widen `ledger.exchange_rate` and `ledger_archive.exchange_rate` to
  `DECIMAL(30,18)` (migration 0037) so the snapshot preserves the precision
  the balanced-leg check depends on.
- Direct rates are unchanged: a stored `base → target` rate is still applied
  as `amount * rate`.

## Consequences

- `B-P0-PRECISION`'s "defined rounding" gap narrows: the inverse direction no
  longer over-credits. The forward direction is still `ROUND(amount * rate,
  prec)`, and the fact that debit and credit are rounded independently (no FX
  P&L account) remains an open owner decision (PR-C).
- Regression coverage in `tests/test_transfer_validity.sh` uses amounts that
  expose the bug (100000 and 1e11 IDR) rather than amounts that hide it.
- The rate snapshot on the CREDIT leg now reflects the rate actually applied
  to 18 decimals; reversals reuse it and stay balanced.
