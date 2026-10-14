-- Migration 0019: monotonic id for pending_transactions.
-- Keeps the per-sender key uniqueness but adds an auto-increment id so
-- "newest transfer" ordering is deterministic (an admin querying an ambiguous
-- reference across senders).
ALTER TABLE pending_transactions
    DROP PRIMARY KEY,
    ADD COLUMN id BIGINT AUTO_INCREMENT PRIMARY KEY FIRST,
    ADD UNIQUE KEY uq_pending_sender_ref (from_email, txn_ref);
