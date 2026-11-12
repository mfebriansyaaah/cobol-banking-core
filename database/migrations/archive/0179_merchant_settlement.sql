CREATE TABLE IF NOT EXISTS merchant_settlement (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    settlement_ref VARCHAR(40) NOT NULL,
    merchant_name VARCHAR(100) NOT NULL,
    settlement_type VARCHAR(20) NOT NULL,
    settlement_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    paid_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','SETTLED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    scheduled_at DATETIME NULL,
    settled_at DATETIME NULL,
    settle_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_merchant_settlement_ref (settlement_ref),
    INDEX idx_merchant_settlement_status (status, settlement_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS merchant_settlement_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    merchant_settlement_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_MCS_audit_actor (actor_email, created_at),
    INDEX idx_MCS_audit_merchant_settlement (merchant_settlement_id, created_at)
) ENGINE=InnoDB;
