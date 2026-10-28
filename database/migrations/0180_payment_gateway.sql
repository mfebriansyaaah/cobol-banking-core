CREATE TABLE IF NOT EXISTS payment_gateway (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    gateway_ref VARCHAR(40) NOT NULL,
    gateway_name VARCHAR(100) NOT NULL,
    gateway_type VARCHAR(20) NOT NULL,
    transaction_limit DECIMAL(18,4) NOT NULL DEFAULT 0,
    processed_volume DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','INACTIVE','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    deactivated_at DATETIME NULL,
    deactivate_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_payment_gateway_ref (gateway_ref),
    INDEX idx_payment_gateway_status (status, gateway_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS payment_gateway_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    payment_gateway_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_PWG_audit_actor (actor_email, created_at),
    INDEX idx_PWG_audit_payment_gateway (payment_gateway_id, created_at)
) ENGINE=InnoDB;
