-- Phase 1 Sprint 1 slice 29: vendor risk and asset maintenance.

CREATE TABLE IF NOT EXISTS vendor_risk (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    vendor_code VARCHAR(40) NOT NULL,
    risk_level ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    score INT NOT NULL DEFAULT 0,
    assessed_by VARCHAR(100) NOT NULL,
    assessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_vendor_risk_vendor (vendor_code, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vendor_risk_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    vendor_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS asset_maintenance (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    asset_code VARCHAR(40) NOT NULL,
    maintenance_type VARCHAR(40) NOT NULL,
    cost DECIMAL(18,4) NOT NULL DEFAULT 0,
    performed_by VARCHAR(100) NOT NULL,
    performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_asset_maintenance_asset (asset_code, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS asset_maintenance_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    asset_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
