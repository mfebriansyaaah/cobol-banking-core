-- Fixed asset lifecycle.

CREATE TABLE IF NOT EXISTS fixed_asset (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    asset_ref VARCHAR(40) NOT NULL,
    asset_name VARCHAR(100) NOT NULL,
    asset_type VARCHAR(20) NOT NULL,
    acquisition_cost DECIMAL(18,4) NOT NULL DEFAULT 0,
    accumulated_depreciation DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','DISPOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    depreciated_at DATETIME NULL,
    disposed_at DATETIME NULL,
    disposal_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_fixed_asset_ref (asset_ref),
    INDEX idx_fixed_asset_status (status, asset_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fixed_asset_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    asset_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_fixed_asset_audit_actor (actor_email, created_at),
    INDEX idx_fixed_asset_audit_asset (asset_id, created_at)
) ENGINE=InnoDB;
