-- Phase 1 Sprint 1 slice 7: payment policy and reconciliation reporting.

CREATE TABLE IF NOT EXISTS payment_policy (
    currency_code CHAR(3) PRIMARY KEY,
    max_per_txn DECIMAL(30,10) NOT NULL DEFAULT 0,
    daily_limit DECIMAL(30,10) NOT NULL DEFAULT 0,
    daily_count INT NOT NULL DEFAULT 0,
    hold_threshold DECIMAL(30,10) NOT NULL DEFAULT 0,
    hold_percent DECIMAL(5,2) NOT NULL DEFAULT 0,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (max_per_txn >= 0 AND daily_limit >= 0 AND daily_count >= 0),
    CHECK (hold_threshold >= 0),
    CHECK (hold_percent BETWEEN 0 AND 100)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payment_profile (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_email VARCHAR(100) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    daily_limit DECIMAL(30,10) NOT NULL DEFAULT 0,
    daily_count INT NOT NULL DEFAULT 0,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_payment_profile (user_email, currency_code),
    CHECK (daily_limit >= 0 AND daily_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payment_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    user_email VARCHAR(100) NULL,
    currency_code CHAR(3) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_payment_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS recon_note (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    finding_id BIGINT NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    note VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_recon_note_finding FOREIGN KEY (finding_id)
        REFERENCES reconciliation_findings(finding_id) ON DELETE CASCADE,
    INDEX idx_recon_note_finding (finding_id, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS recon_sla_policy (
    policy_code VARCHAR(32) PRIMARY KEY,
    age_hours INT NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (age_hours BETWEEN 1 AND 8760)
) ENGINE=InnoDB;

INSERT IGNORE INTO recon_sla_policy (policy_code, age_hours, enabled, updated_by)
VALUES ('DEFAULT', 24, TRUE, 'SYSTEM');

CREATE TABLE IF NOT EXISTS recon_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    finding_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_recon_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
