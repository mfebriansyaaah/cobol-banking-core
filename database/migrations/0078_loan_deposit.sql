-- Phase 1 Sprint 1 slice 23: loan lifecycle and term deposits.

CREATE TABLE IF NOT EXISTS loan_application (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    principal DECIMAL(18,4) NOT NULL,
    currency CHAR(3) NOT NULL,
    term_months INT NOT NULL,
    interest_rate DECIMAL(9,4) NOT NULL DEFAULT 0,
    status ENUM('PENDING','APPROVED','REJECTED','DISBURSED','CLOSED') NOT NULL DEFAULT 'PENDING',
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(100) NULL,
    decided_at DATETIME NULL,
    disbursed_at DATETIME NULL,
    CHECK (term_months BETWEEN 1 AND 360)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loan_repayment (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    loan_id BIGINT NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','PAID') NOT NULL DEFAULT 'PENDING',
    due_date DATE NULL,
    paid_at DATETIME NULL,
    CONSTRAINT fk_loan_repayment_loan FOREIGN KEY (loan_id)
        REFERENCES loan_application(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loan_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    loan_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_loan_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS deposit_account (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    principal DECIMAL(18,4) NOT NULL,
    currency CHAR(3) NOT NULL,
    term_months INT NOT NULL,
    interest_rate DECIMAL(9,4) NOT NULL DEFAULT 0,
    status ENUM('PENDING','ACTIVE','MATURED','CLOSED') NOT NULL DEFAULT 'ACTIVE',
    maturity_date DATE NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (term_months BETWEEN 1 AND 360)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS deposit_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    deposit_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_deposit_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
