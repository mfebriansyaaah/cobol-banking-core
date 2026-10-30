-- PR-501: Chargeback — ledger + audit.

CREATE TABLE IF NOT EXISTS chargeback_ledger (
    entry_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NOT NULL,
    entry_type ENUM('HOLD','RELEASE','DEBIT','CREDIT') NOT NULL,
    amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'IDR',
    gl_journal_id INT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cb_ledger_case FOREIGN KEY (case_id)
        REFERENCES chargeback_case (case_id) ON DELETE CASCADE,
    INDEX idx_cb_ledger_case (case_id, entry_type),
    CHECK (amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS chargeback_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_cb_audit_actor (actor_email, created_at),
    INDEX idx_cb_audit_case (case_id, created_at)
) ENGINE=InnoDB;
