# Unambiguous transfer reversal (per-sender transaction references)

Status: accepted
Date: 2026-10-15
Phase: Ledger/Transactions hardening (FASE A).

## Context

A transfer's reference (`txn_ref`) is the client idempotency key, which is
unique **per sender**, not globally (`pending_transactions` UNIQUE
`(from_email, txn_ref)`). Two senders can therefore use the same reference.
`REVERSE_TRANSFER` looked up the ledger rows by `txn_ref` alone
(`WHERE txn_ref = ? AND type='DEBIT' LIMIT 1`, no `ORDER BY`), and
`transfer_reversals` was keyed by `orig_ref` alone. A shared reference could
make an admin reverse the **wrong** transfer, and marked every transfer with
that reference as already reversed.

## Decision

- Record the transfer's sender on both `ledger` rows
  (`ledger.from_email`, migration 0026), so the DEBIT and CREDIT of one transfer
  pair unambiguously: `WHERE txn_ref = ? AND type = ? AND from_email = ?`.
- `REVERSE_TRANSFER` gains an optional `p3=sender`:
  - with a sender, it reverses exactly that sender's transfer;
  - without a sender, it counts the distinct senders for the reference and
    refuses with `ERROR|AMBIGUOUS_TRANSACTION` (HTTP 409) when more than one
    exists (and `UNKNOWN_TRANSACTION` when none).
- `transfer_reversals` is keyed by `(orig_ref, from_email)`, so each transfer is
  reversed at most once independently.
- `TX_STATUS` marks REVERSED scoped by the transfer's sender too.

## Consequences

- A shared reference can no longer reverse the wrong transfer, and reversing one
  transfer does not affect another sender's transfer with the same reference.
- Reversal of a shared reference now requires the `sender`; single-sender
  references keep working unchanged. Covered by `tests/test_transfer_reversal.sh`.
- Legacy ledger rows (pre-migration) have `from_email` NULL and are not matched
  by a sender-scoped lookup; new transfers always record it.
