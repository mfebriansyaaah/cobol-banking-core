CREATE TABLE IF NOT EXISTS digital_banking (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    digital_ref VARCHAR(40) NOT NULL,
    service_name VARCHAR(100) NOT NULL,
    service_type VARCHAR(20) NOT NULL,
    transaction_cap DECIMAL(18,4) NOT NULL DEFAULT 0,
    current_usage DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','INACTIVE','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    deactivated_at DATETIME NULL,
    deactivate_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_digital_banking_ref (digital_ref),
    INDEX idx_digital_banking_status (status, service_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS digital_banking_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    digital_banking_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_DGB_audit_actor (actor_email, created_at),
    INDEX idx_DGB_audit_digital_banking (digital_banking_id, created_at)
) ENGINE=InnoDB;
