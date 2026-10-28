CREATE TABLE IF NOT EXISTS mobile_wallet (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    wallet_ref VARCHAR(40) NOT NULL,
    wallet_name VARCHAR(100) NOT NULL,
    wallet_type VARCHAR(20) NOT NULL,
    topup_limit DECIMAL(18,4) NOT NULL DEFAULT 0,
    spent_today DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_mobile_wallet_ref (wallet_ref),
    INDEX idx_mobile_wallet_status (status, wallet_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS mobile_wallet_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    mobile_wallet_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_MBW_audit_actor (actor_email, created_at),
    INDEX idx_MBW_audit_mobile_wallet (mobile_wallet_id, created_at)
) ENGINE=InnoDB;
