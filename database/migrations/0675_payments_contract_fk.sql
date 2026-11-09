-- Fase 4 (payments 10/10): contract hardening.
-- 1) Client-supplied settle idempotency: (clearing_id, idempotency_key) is
--    unique. A repeated key replays the stored outcome instead of posting
--    again; a key reused with a different amount is a conflict. Stale
--    PENDING rows (owner crashed) are taken over after 5 minutes.
-- 2) Linkage columns become real foreign keys instead of bare integers.
CREATE TABLE IF NOT EXISTS payment_settle_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    clearing_id BIGINT NOT NULL,
    idempotency_key VARCHAR(64) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','DONE') NOT NULL DEFAULT 'PENDING',
    gl_journal_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_settle_idem (clearing_id, idempotency_key),
    INDEX idx_settle_req_clearing (clearing_id),
    CONSTRAINT fk_settle_req_clearing FOREIGN KEY (clearing_id)
        REFERENCES payment_clearing(id) ON DELETE CASCADE
) ENGINE=InnoDB;

ALTER TABLE payment_clearing
    ADD CONSTRAINT fk_payment_clearing_gl FOREIGN KEY (gl_journal_id)
        REFERENCES gl_journal(id);
ALTER TABLE payment_hold
    ADD CONSTRAINT fk_payment_hold_journal FOREIGN KEY (journal_id)
        REFERENCES journal_entries(journal_id);
