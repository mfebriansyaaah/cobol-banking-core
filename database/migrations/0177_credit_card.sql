CREATE TABLE IF NOT EXISTS credit_card (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    card_ref VARCHAR(40) NOT NULL,
    cardholder_name VARCHAR(100) NOT NULL,
    card_type VARCHAR(20) NOT NULL,
    credit_limit DECIMAL(18,4) NOT NULL DEFAULT 0,
    outstanding_balance DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CANCELLED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    cancelled_at DATETIME NULL,
    cancel_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_credit_card_ref (card_ref),
    INDEX idx_credit_card_status (status, card_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS credit_card_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    credit_card_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_CRC_audit_actor (actor_email, created_at),
    INDEX idx_CRC_audit_credit_card (credit_card_id, created_at)
) ENGINE=InnoDB;
