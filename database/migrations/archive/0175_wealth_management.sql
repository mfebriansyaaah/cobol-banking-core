CREATE TABLE IF NOT EXISTS wealth_management (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    wealth_ref VARCHAR(40) NOT NULL,
    client_name VARCHAR(100) NOT NULL,
    wealth_type VARCHAR(20) NOT NULL,
    portfolio_value DECIMAL(18,4) NOT NULL DEFAULT 0,
    managed_value DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_wealth_management_ref (wealth_ref),
    INDEX idx_wealth_management_status (status, wealth_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS wealth_management_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    wealth_management_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_WLM_audit_actor (actor_email, created_at),
    INDEX idx_WLM_audit_wealth_management (wealth_management_id, created_at)
) ENGINE=InnoDB;
