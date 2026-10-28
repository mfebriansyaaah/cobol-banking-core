CREATE TABLE IF NOT EXISTS internet_banking (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    inet_ref VARCHAR(40) NOT NULL,
    user_name VARCHAR(100) NOT NULL,
    inet_type VARCHAR(20) NOT NULL,
    transfer_limit DECIMAL(18,4) NOT NULL DEFAULT 0,
    transferred_today DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','INACTIVE','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    deactivated_at DATETIME NULL,
    deactivate_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_internet_banking_ref (inet_ref),
    INDEX idx_internet_banking_status (status, inet_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS internet_banking_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    internet_banking_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_INB_audit_actor (actor_email, created_at),
    INDEX idx_INB_audit_internet_banking (internet_banking_id, created_at)
) ENGINE=InnoDB;
