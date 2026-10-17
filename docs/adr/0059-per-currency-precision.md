# Per-currency precision and exact money comparison (Gate 1)

Status: accepted
Date: 2026-10-17
Phase: Gate 1 — accounting foundation.

## Context

PRD section 4.B requires currency-specific minor units end to end and no
fixed `x100` scaling. The transfer path violated this in a way the suites
could not see: every module compiles with `DECIMAL-POINT IS COMMA`, so
COBOL `NUMVAL` reads a dot as a thousands separator (`"100.01"` parses as
10001). The old caps compensated with a fixed `* 100`, which is exact only
for amounts written with exactly two fraction digits:

- `"101"` (integer) compared as 101 against a cap scaled to 10000, so a
  whole-unit amount over the cap was silently allowed;
- `"7.5"` (one decimal) compared as 75 while SQL posted 7.50 — limit math
  and posted money disagreed;
- any 0-decimal currency amount mixed unscaled integers against scaled caps.

The old suites only exercised two-decimal amounts, so all of this passed unnoticed.

## Decision

- **Canonical parse:** money strings are normalized (dot to comma) before
  `NUMVAL` into `S9(16)V9999` major-unit fields — amounts, balances,
  rolling totals, replay intents, and reversal clawbacks. COBOL never
  rounds money; MySQL `ROUND(?, prec)` at posting/display is the single
  rounding point (round half away from zero).
- **Precision gate:** after account resolution, the transfer is refused
  unless the amount's fraction digits fit the sender currency's `prec_val`
  and both currencies' precisions are within 0–4 (the `DECIMAL(18,4)`
  schema maximum). Anything beyond fails closed as `CURRENCY_INACTIVE`.
- **Caps:** `TRANSFER_MAX_PER_TXN`/`TRANSFER_DAILY_LIMIT` stay whole units
  of the sender currency, digits only, compared in exact major units. A new
  `env_or_raw` bridge helper preserves the raw text so COBOL can fail
  closed (`LIMIT_EXCEEDED`/`DAILY_LIMIT_EXCEEDED`) on dotted or malformed
  settings instead of enforcing a silently different number.
- **Reads:** sufficiency, rolling-total, replay, and reversal reads use
  full stored precision; `CHECK_BALANCE`/`RECONCILE` display via
  `FORMAT(x, prec)` with grouping commas stripped (the binary-protocol
  string binding otherwise inherits the expression's scale, e.g.
  `1000.0000` for a `ROUND(x, column)`).
- **Deliberately out of scope:** rate validity windows, fees,
  `prec_val > 4` support, and the two-decimal `TX_STATUS` amount readout
  (display only; posted money is exact).

## Consequences

- `tests/test_transfer_limits.sh` grows 10 → 27 checks: integer/1dp
  major-unit boundaries, fail-closed caps, IDR (prec 0), and a 3-decimal
  currency (exact debit, over-precision refusal, milli-level caps).
- The gateway amount shape allows up to four fraction digits (syntax
  only); COBOL remains the precision authority, proven by a gateway test
  where USD refuses `1.234` with `INVALID_AMOUNT`.
- Baseline and `docs/STATUS.md` headline counts move 733 → 750 assertions.
