CREATE TABLE IF NOT EXISTS treasury_deal (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    deal_ref VARCHAR(40) NOT NULL,
    counterparty VARCHAR(100) NOT NULL,
    deal_type VARCHAR(20) NOT NULL,
    notional DECIMAL(18,4) NOT NULL DEFAULT 0,
    mtm_value DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    traded_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_treasury_deal_ref (deal_ref),
    INDEX idx_treasury_deal_status (status, deal_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS treasury_deal_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    treasury_deal_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_treasury_deal_audit_actor (actor_email, created_at),
    INDEX idx_treasury_deal_audit_treasury (treasury_deal_id, created_at)
) ENGINE=InnoDB;
