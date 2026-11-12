-- Phase 1 Sprint 1 slice 24: FX deals and treasury positions.

CREATE TABLE IF NOT EXISTS fx_deal (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    deal_ref VARCHAR(64) NOT NULL,
    currency_pair VARCHAR(20) NOT NULL,
    side ENUM('BUY','SELL') NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    rate DECIMAL(18,8) NOT NULL,
    value_date DATE NULL,
    status ENUM('PENDING','CONFIRMED','SETTLED','CANCELLED') NOT NULL DEFAULT 'PENDING',
    counterparty VARCHAR(100) NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fx_deal_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    deal_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_fx_deal_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS treasury_position (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    currency CHAR(3) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    as_of_date DATE NOT NULL,
    status ENUM('OPEN','CLOSED') NOT NULL DEFAULT 'OPEN',
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS treasury_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    position_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_treasury_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
