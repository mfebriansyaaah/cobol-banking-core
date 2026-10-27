CREATE TABLE IF NOT EXISTS remittance (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    remit_ref VARCHAR(40) NOT NULL,
    beneficiary VARCHAR(100) NOT NULL,
    remit_type VARCHAR(20) NOT NULL,
    amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    fee_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','SETTLED','CANCELLED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    settled_at DATETIME NULL,
    cancelled_at DATETIME NULL,
    cancel_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_remittance_ref (remit_ref),
    INDEX idx_remittance_status (status, remit_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS remittance_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    remittance_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_remittance_audit_actor (actor_email, created_at),
    INDEX idx_remittance_audit_remittance (remittance_id, created_at)
) ENGINE=InnoDB;
