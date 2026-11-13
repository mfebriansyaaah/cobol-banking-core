-- Unified idempotency mirror (maint-14A): one generic request table for
-- every money action with a client-supplied key, mirroring the ten
-- per-action `*_request` tables (card_capture/repay/reverse,
-- deposit_settle/open/close, loan_disburse/repay, collection_pay,
-- payment_settle). ADR-0008 protocol is unchanged: a key claims a PENDING
-- row and owns it; a repeat replays the stored DONE outcome (or conflicts
-- on different details); a fresh PENDING owned by someone else is refused;
-- a PENDING row older than 5 minutes is taken over; refusals before
-- posting delete only the owned PENDING row.
--
-- In this release the legacy tables stay the decision-makers
-- (dual-write, legacy-truth reads). cobol/copy/common_idem.cpy writes
-- both stores on every transition; the suites prove the mirror
-- converges. No legacy table is dropped here; reads cut over later.
CREATE TABLE IF NOT EXISTS idempotency_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    scope VARCHAR(32) NOT NULL,
    entity_ref VARCHAR(64) NOT NULL DEFAULT '',
    idem_key VARCHAR(64) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    details VARCHAR(500) NOT NULL DEFAULT '',
    status ENUM('PENDING','DONE') NOT NULL DEFAULT 'PENDING',
    gl_journal_id BIGINT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_idem_scope_entity_key (scope, entity_ref, idem_key),
    INDEX idx_idem_scope_key (scope, idem_key)
) ENGINE=InnoDB;
