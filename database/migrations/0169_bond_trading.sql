CREATE TABLE IF NOT EXISTS bond_trading (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    bond_ref VARCHAR(40) NOT NULL,
    issuer_name VARCHAR(100) NOT NULL,
    bond_type VARCHAR(20) NOT NULL,
    face_value DECIMAL(18,4) NOT NULL DEFAULT 0,
    market_value DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','MATURED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    issued_at DATETIME NULL,
    matured_at DATETIME NULL,
    mature_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_bond_trading_ref (bond_ref),
    INDEX idx_bond_trading_status (status, bond_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS bond_trading_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    bond_trading_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_BND_audit_actor (actor_email, created_at),
    INDEX idx_BND_audit_bond_trading (bond_trading_id, created_at)
) ENGINE=InnoDB;
