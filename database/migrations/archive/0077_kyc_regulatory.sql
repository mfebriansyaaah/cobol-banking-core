-- Phase 1 Sprint 1 slice 22: KYC reviews and regulatory reports.

CREATE TABLE IF NOT EXISTS kyc_review (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    review_type ENUM('ONBOARDING','PERIODIC','ENHANCED') NOT NULL,
    status ENUM('PENDING','APPROVED','REJECTED','ESCALATED') NOT NULL DEFAULT 'PENDING',
    risk_level ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    due_date DATE NULL,
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(100) NULL,
    decided_at DATETIME NULL,
    INDEX idx_kyc_review_status (status, due_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS kyc_review_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    review_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_kyc_review_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS regulatory_report (
    report_code VARCHAR(40) PRIMARY KEY,
    regulator ENUM('OJK','BI','PPATK') NOT NULL,
    report_type VARCHAR(40) NOT NULL,
    period VARCHAR(40) NOT NULL,
    status ENUM('DRAFT','SUBMITTED','ACCEPTED','REJECTED') NOT NULL DEFAULT 'DRAFT',
    row_count BIGINT NOT NULL DEFAULT 0,
    checksum CHAR(64) NULL,
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    submitted_at DATETIME NULL,
    decided_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS regulatory_report_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    report_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_regulatory_report_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
