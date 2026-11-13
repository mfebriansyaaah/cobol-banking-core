CREATE TABLE IF NOT EXISTS merchant (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    merchant_ref VARCHAR(40) NOT NULL,
    merchant_name VARCHAR(100) NOT NULL,
    merchant_type VARCHAR(20) NOT NULL,
    transaction_volume DECIMAL(18,4) NOT NULL DEFAULT 0,
    settled_volume DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_merchant_ref (merchant_ref),
    INDEX idx_merchant_status (status, merchant_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS merchant_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    merchant_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_merchant_audit_actor (actor_email, created_at),
    INDEX idx_merchant_audit_merchant (merchant_id, created_at)
) ENGINE=InnoDB;
