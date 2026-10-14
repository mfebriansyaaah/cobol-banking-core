-- Migration 0015: scope transfer idempotency keys per sender.
-- Two different senders may use the same key without colliding; the key only
-- has to be unique within one sender's transfers.
ALTER TABLE pending_transactions
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (from_email, txn_ref);
