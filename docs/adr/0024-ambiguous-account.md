# Ambiguous account selection is refused

Status: accepted
Date: 2026-10-15
Phase: Ledger/Transactions hardening (FASE C).

## Context

A user may hold several accounts (one per currency via `UNIQUE
(user_id, currency_id)`). When a transfer did not pin the sender's or
recipient's currency (`fromCurrency`/`toCurrency`, transfer `p5`/`p6`), the
account query (`WHERE users.email = ?`, no `ORDER BY`/`LIMIT`) returned several
rows and `SQL_PREPARE_EXEC` silently used the **first** one — a nondeterministic
account selection.

## Decision

- Before starting the transaction, `TRANSFER` counts the sender's accounts when
  `p5` is absent, and the recipient's accounts when `p6` is absent.
- If the count is greater than one, it refuses with `ERROR|AMBIGUOUS_ACCOUNT`
  (HTTP 409) and asks the caller to pin the currency. A count of zero keeps the
  existing `ACCOUNT_NOT_FOUND`/`TARGET_NOT_FOUND` behaviour.
- Single-account users (the common case) are unaffected and need no pin.

## Consequences

- A multi-currency user can no longer have a transfer silently drawn from an
  arbitrary account; the client must specify `fromCurrency`/`toCurrency`.
- Two extra counts run per unpinned transfer; negligible, and only when a pin is
  omitted.
- Covered by `tests/test_transfer_validity.sh` (pinned selection still works;
  unpinned multi-account is `AMBIGUOUS_ACCOUNT`).
