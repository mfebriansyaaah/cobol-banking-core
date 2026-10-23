-- Phase 1 Sprint 1 slice 33: fee waiver and limit profiles.

CREATE TABLE IF NOT EXISTS fee_waiver_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    fee_type VARCHAR(40) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
    reason VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(100) NULL,
    decided_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fee_waiver_request_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    waiver_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS limit_profile (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    daily_limit DECIMAL(18,4) NOT NULL,
    monthly_limit DECIMAL(18,4) NOT NULL,
    velocity_tier VARCHAR(20) NOT NULL DEFAULT 'STANDARD',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_limit_profile_customer (customer_email)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS limit_profile_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    profile_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
