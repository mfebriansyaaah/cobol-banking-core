-- FX hedging lifecycle.

CREATE TABLE IF NOT EXISTS fx_hedging (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    hedge_ref VARCHAR(40) NOT NULL,
    counterparty VARCHAR(100) NOT NULL,
    hedge_type VARCHAR(20) NOT NULL,
    notional_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    settled_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','SETTLED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    settled_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_fx_hedging_ref (hedge_ref),
    INDEX idx_fx_hedging_status (status, hedge_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fx_hedging_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    hedge_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_fx_hedging_audit_actor (actor_email, created_at),
    INDEX idx_fx_hedging_audit_hedge (hedge_id, created_at)
) ENGINE=InnoDB;
