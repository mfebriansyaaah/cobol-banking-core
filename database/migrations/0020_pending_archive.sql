-- Migration 0020: archive pruned transfer intents instead of dropping them.
-- Preserves idempotency/transfer history for traceability; the live table stays
-- bounded and the replay window is unchanged (the live table is authoritative).
CREATE TABLE IF NOT EXISTS pending_transactions_archive (
    id BIGINT PRIMARY KEY,
    txn_ref VARCHAR(50) NOT NULL,
    from_email VARCHAR(100) NOT NULL,
    to_email VARCHAR(100) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING', 'COMMITTED', 'FAILED'),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_pending_archive_created (created_at)
) ENGINE=InnoDB;
