CREATE TABLE IF NOT EXISTS asset_management (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    asset_ref VARCHAR(40) NOT NULL,
    asset_name VARCHAR(100) NOT NULL,
    asset_type VARCHAR(20) NOT NULL,
    acquisition_cost DECIMAL(18,4) NOT NULL DEFAULT 0,
    current_value DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','DISPOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    acquired_at DATETIME NULL,
    disposed_at DATETIME NULL,
    dispose_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_asset_management_ref (asset_ref),
    INDEX idx_asset_management_status (status, asset_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS asset_management_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    asset_management_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ASM_audit_actor (actor_email, created_at),
    INDEX idx_ASM_audit_asset_management (asset_management_id, created_at)
) ENGINE=InnoDB;
