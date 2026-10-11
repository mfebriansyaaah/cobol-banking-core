# Idempotent transfers via an idempotency key

Status: accepted
Date: 2026-10-11
Phase: scalability/reliability item - makes transfers replay-safe.

## Context

`TRANSFER` moves money with a debit + credit + ledger pair inside one
transaction. A client that retries (gateway timeout, network blip, double
submit) could apply the movement twice - the most expensive failure a banking
core can produce.

## Decision

`TRANSFER` takes an optional fourth parameter: the **idempotency key**.
- The key doubles as the transaction reference (`txn_ref`) in the ledger.
- Before moving money, the key is recorded as a `pending_transactions` intent
  (`PENDING`) inside the same transaction.
- On success the intent is marked `COMMITTED` and everything commits together;
  on failure the whole transaction rolls back, so **an intent only persists
  when the movement committed**.
- A repeated key therefore finds a `COMMITTED` row and returns the prior
  success **without moving money again** (`ERROR|TRANSFER_IN_PROGRESS` only
  reaches a concurrent second attempt on duplicate key).

## Why this shape

- A persisted intent equals a committed movement, so there is no separate
  expiry/sweeper logic and no way to be idempotent-but-pending forever.
- Distinct keys keep creating distinct movements; legacy callers that omit the
  key keep the timestamp-generated reference.
- The gateway forwards its `Idempotency-Key` header as the key, so HTTP
  clients follow the standard header convention.

## Consequences

- Ledger references carry client-chosen values when a key is used (max 50 chars, validated by the gateway).
- `pending_transactions` rows are owner-scoped and cascade on user deletion.
- The key lives at the transfer level; a generic idempotency middleware for other actions is future work.
