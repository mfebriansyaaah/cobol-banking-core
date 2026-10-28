CREATE TABLE IF NOT EXISTS portfolio_management (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    portfolio_ref VARCHAR(40) NOT NULL,
    portfolio_name VARCHAR(100) NOT NULL,
    portfolio_type VARCHAR(20) NOT NULL,
    target_return DECIMAL(18,4) NOT NULL DEFAULT 0,
    actual_return DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_portfolio_management_ref (portfolio_ref),
    INDEX idx_portfolio_management_status (status, portfolio_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS portfolio_management_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    portfolio_management_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_POM_audit_actor (actor_email, created_at),
    INDEX idx_POM_audit_portfolio_management (portfolio_management_id, created_at)
) ENGINE=InnoDB;
