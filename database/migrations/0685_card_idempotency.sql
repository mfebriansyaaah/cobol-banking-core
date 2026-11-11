-- Card Fase 2: idempotency keys for CAPTURE, REPAY and REVERSAL.
-- Mirrors loan/deposit request tables: a client-supplied key (P5) claims a
-- PENDING request row and owns it; a repeat replays the stored DONE outcome
-- (or conflicts on a different amount) instead of posting again; a key
-- whose owner is still working is refused (*_IN_PROGRESS) so two owners
-- never post twice; a PENDING row older than 5 minutes is taken over (owner
-- crashed). Refusals before posting delete the owned PENDING row so the
-- key stays usable.
CREATE TABLE IF NOT EXISTS card_capture_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    card_id BIGINT NOT NULL,
    idempotency_key VARCHAR(64) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','DONE') NOT NULL DEFAULT 'PENDING',
    gl_journal_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_capture_idem (card_id, idempotency_key),
    INDEX idx_capture_req_card (card_id),
    CONSTRAINT fk_capture_req_card FOREIGN KEY (card_id)
        REFERENCES card_account (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS card_repay_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    card_id BIGINT NOT NULL,
    idempotency_key VARCHAR(64) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','DONE') NOT NULL DEFAULT 'PENDING',
    gl_journal_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_repay_idem (card_id, idempotency_key),
    INDEX idx_repay_req_card (card_id),
    CONSTRAINT fk_repay_req_card FOREIGN KEY (card_id)
        REFERENCES card_account (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS card_reverse_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    card_id BIGINT NOT NULL,
    idempotency_key VARCHAR(64) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','DONE') NOT NULL DEFAULT 'PENDING',
    gl_journal_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_reverse_idem (card_id, idempotency_key),
    INDEX idx_reverse_req_card (card_id),
    CONSTRAINT fk_reverse_req_card FOREIGN KEY (card_id)
        REFERENCES card_account (id) ON DELETE CASCADE
) ENGINE=InnoDB;
