CREATE TABLE IF NOT EXISTS collateral_mgmt (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    collateral_ref VARCHAR(40) NOT NULL,
    asset_name VARCHAR(100) NOT NULL,
    collateral_type VARCHAR(20) NOT NULL,
    pledged_value DECIMAL(18,4) NOT NULL DEFAULT 0,
    haircut_value DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','RELEASED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    pledged_at DATETIME NULL,
    released_at DATETIME NULL,
    release_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_collateral_mgmt_ref (collateral_ref),
    INDEX idx_collateral_mgmt_status (status, collateral_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS collateral_mgmt_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    collateral_mgmt_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_collateral_mgmt_audit_actor (actor_email, created_at),
    INDEX idx_collateral_mgmt_audit_collateral (collateral_mgmt_id, created_at)
) ENGINE=InnoDB;
