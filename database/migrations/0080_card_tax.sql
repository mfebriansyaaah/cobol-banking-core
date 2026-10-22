-- Phase 1 Sprint 1 slice 25: card management and tax reporting.

CREATE TABLE IF NOT EXISTS card_account (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    card_ref VARCHAR(64) NOT NULL,
    customer_email VARCHAR(100) NOT NULL,
    card_type ENUM('DEBIT','CREDIT','PREPAID') NOT NULL,
    status ENUM('ACTIVE','BLOCKED','CLOSED') NOT NULL DEFAULT 'ACTIVE',
    limit_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS card_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    card_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_card_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tax_report (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    report_ref VARCHAR(64) NOT NULL,
    tax_type ENUM('VAT','INCOME','WITHHOLDING') NOT NULL,
    period VARCHAR(40) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    currency CHAR(3) NOT NULL,
    status ENUM('DRAFT','FILED','PAID','CLOSED') NOT NULL DEFAULT 'DRAFT',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tax_report_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    report_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_tax_report_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
