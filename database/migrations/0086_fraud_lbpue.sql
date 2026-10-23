-- Phase 1 Sprint 1 slice 31: fraud review queue and LBPUE reporting.

CREATE TABLE IF NOT EXISTS fraud_review (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_ref VARCHAR(64) NOT NULL,
    customer_email VARCHAR(100) NOT NULL,
    status ENUM('OPEN','REVIEWING','CLEARED','BLOCKED') NOT NULL DEFAULT 'OPEN',
    risk_score INT NOT NULL DEFAULT 0,
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(100) NULL,
    decided_at DATETIME NULL,
    INDEX idx_fraud_review_status (status, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fraud_review_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    review_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_fraud_review_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS lbpue_report (
    report_code VARCHAR(40) PRIMARY KEY,
    period VARCHAR(20) NOT NULL,
    status ENUM('DRAFT','GENERATED','SUBMITTED') NOT NULL DEFAULT 'DRAFT',
    row_count BIGINT NOT NULL DEFAULT 0,
    checksum CHAR(64) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    submitted_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS lbpue_report_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    report_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_lbpue_report_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
