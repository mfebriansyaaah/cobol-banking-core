-- D6 treasury: liquidity forecasts and positions.

CREATE TABLE IF NOT EXISTS treasury_liquidity (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    liq_ref VARCHAR(40) NOT NULL,
    amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL,
    source_ref VARCHAR(40) NULL,
    status ENUM('OPEN','PROJECTED','REALIZED','CLOSED','ADJUSTED') NOT NULL DEFAULT 'OPEN',
    projected_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    realized_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    projected_at DATETIME NULL,
    realized_at DATETIME NULL,
    closed_at DATETIME NULL,
    closure_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_treasury_liquidity_ref (liq_ref),
    INDEX idx_treasury_liquidity_status (status, currency)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS treasury_liquidity_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    liq_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_treasury_liquidity_audit_actor (actor_email, created_at),
    INDEX idx_treasury_liquidity_audit_case (liq_id, created_at)
) ENGINE=InnoDB;
