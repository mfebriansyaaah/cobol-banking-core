# TX_STATUS amount at the sender currency's precision

Status: accepted
Date: 2026-10-17
Phase: Gate 1 — accounting foundation (B-P0-PRECISION).

## Context

`TX_STATUS` reported a transfer's amount with a hardcoded
`CONCAT(ROUND(amount, 2))`, so a transfer denominated in a zero-decimal
currency (IDR) was shown as `100.00` and a four-decimal currency would be
truncated to two. The amount is the sender's, and `pending_transactions` does
not record the currency, so the readout had no precision to use.

## Decision

- Format the amount at the sender currency's precision, resolved at read time:
  1. the ledger `DEBIT` leg for `(txn_ref, from_email)` names the posted
     currency (authoritative for `COMMITTED`/`REVERSED`);
  2. a still-pending intent (no ledger row yet) falls back to the sender's
     account currency when the sender holds exactly one currency;
  3. otherwise 2 decimals.
- Use `REPLACE(FORMAT(amount, <precision>), ',', '')`, matching the
  `CHECK_BALANCE` projection. `ROUND` is deliberately not used: MySQL keeps
  `ROUND`'s input scale when the precision argument is a subquery it cannot
  fold at prepare time, so `ROUND(amount, <subquery>)` would not reduce the
  decimals.
- The three query variants (sender filter, admin unfiltered, owner) now share
  one `STRING ... WITH POINTER` prefix and append their own filter, so the
  precision expression is written once.

## Consequences

- `B-P0-PRECISION`'s readout gap closes: an IDR transfer reads `100`, a USD
  transfer `100.00`, matching the currency. No schema or write-path change.
- The amount is still a readout of the intent (the authoritative posted
  amounts live in the ledger); this decision only fixes its formatting.
