CREATE TABLE IF NOT EXISTS bank_guarantee (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    guarantee_ref VARCHAR(40) NOT NULL,
    beneficiary_name VARCHAR(100) NOT NULL,
    guarantee_type VARCHAR(20) NOT NULL,
    guarantee_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    claimed_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    issued_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_bank_guarantee_ref (guarantee_ref),
    INDEX idx_bank_guarantee_status (status, guarantee_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS bank_guarantee_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    bank_guarantee_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_BKG_audit_actor (actor_email, created_at),
    INDEX idx_BKG_audit_bank_guarantee (bank_guarantee_id, created_at)
) ENGINE=InnoDB;
