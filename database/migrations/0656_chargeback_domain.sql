-- PR-501: Chargeback — case, evidence, event.
-- New domain tables; legacy generic `chargeback`, `dispute_management`
-- tables are left untouched (deprecation in PR-504).

CREATE TABLE IF NOT EXISTS chargeback_case (
    case_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_ref VARCHAR(40) NOT NULL,
    card_transaction_id BIGINT NULL,
    card_id BIGINT NULL,
    merchant_id BIGINT NULL,
    amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'IDR',
    reason_code VARCHAR(20) NOT NULL DEFAULT 'UNKNOWN',
    status ENUM('OPEN','EVIDENCE_REQUIRED','REPRESENTED','ACCEPTED','REJECTED','ARBITRATION','CLOSED') NOT NULL DEFAULT 'OPEN',
    deadline DATE NULL,
    assigned_to VARCHAR(100) NULL,
    resolution VARCHAR(255) NULL,
    opened_by VARCHAR(100) NOT NULL,
    opened_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at DATETIME NULL,
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cb_case_txn FOREIGN KEY (card_transaction_id)
        REFERENCES card_transaction (id) ON DELETE SET NULL,
    CONSTRAINT fk_cb_case_merchant FOREIGN KEY (merchant_id)
        REFERENCES merchant (id) ON DELETE SET NULL,
    UNIQUE KEY uq_chargeback_case_ref (case_ref),
    INDEX idx_chargeback_case_status (status, deadline),
    INDEX idx_chargeback_case_txn (card_transaction_id),
    CHECK (amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS chargeback_evidence (
    evidence_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NOT NULL,
    evidence_type VARCHAR(40) NOT NULL DEFAULT 'DOCUMENT',
    document_ref VARCHAR(100) NULL,
    note VARCHAR(255) NULL,
    submitted_by VARCHAR(100) NOT NULL,
    submitted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cb_evidence_case FOREIGN KEY (case_id)
        REFERENCES chargeback_case (case_id) ON DELETE CASCADE,
    INDEX idx_cb_evidence_case (case_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS chargeback_event (
    event_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NOT NULL,
    event_type ENUM('OPENED','ASSIGNED','EVIDENCE_ADDED','REPRESENTED','ACCEPTED','REJECTED','ARBITRATION','CLOSED') NOT NULL,
    event_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    deadline DATE NULL,
    CONSTRAINT fk_cb_event_case FOREIGN KEY (case_id)
        REFERENCES chargeback_case (case_id) ON DELETE CASCADE,
    INDEX idx_cb_event_case (case_id, event_at)
) ENGINE=InnoDB;
