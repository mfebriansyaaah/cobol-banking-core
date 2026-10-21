-- Phase 1 Sprint 1 slice 5: statement archive and EOD job execution.

CREATE TABLE IF NOT EXISTS statement_run (
    id INT AUTO_INCREMENT PRIMARY KEY,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    currency_code CHAR(3) NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    account_count BIGINT NOT NULL DEFAULT 0,
    generated_count BIGINT NOT NULL DEFAULT 0,
    failed_count BIGINT NOT NULL DEFAULT 0,
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    version INT NOT NULL DEFAULT 0,
    INDEX idx_statement_run_status (status, period_end),
    CHECK (account_count >= 0 AND generated_count >= 0 AND failed_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_archive (
    id INT AUTO_INCREMENT PRIMARY KEY,
    run_id INT NOT NULL,
    account_email VARCHAR(100) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    opening_balance DECIMAL(30,10) NOT NULL DEFAULT 0,
    closing_balance DECIMAL(30,10) NOT NULL DEFAULT 0,
    total_debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    total_credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    row_count BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_statement_account (run_id, account_email, currency_code),
    CONSTRAINT fk_statement_archive_run FOREIGN KEY (run_id)
        REFERENCES statement_run(id) ON DELETE CASCADE,
    CHECK (row_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_archive_line (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    archive_id INT NOT NULL,
    line_no BIGINT NOT NULL,
    posting_date DATE NOT NULL,
    txn_ref VARCHAR(50) NOT NULL,
    source VARCHAR(20) NOT NULL,
    debit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    credit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    balance_after DECIMAL(30,10) NOT NULL DEFAULT 0,
    description VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_statement_line (archive_id, line_no),
    CONSTRAINT fk_statement_line_archive FOREIGN KEY (archive_id)
        REFERENCES statement_archive(id) ON DELETE CASCADE,
    CHECK (line_no >= 1),
    CHECK (debit_amount >= 0 AND credit_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id INT NULL,
    account_email VARCHAR(100) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_statement_audit_actor (actor_email, created_at),
    INDEX idx_statement_audit_run (run_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS eod_job_run (
    id INT AUTO_INCREMENT PRIMARY KEY,
    business_date DATE NOT NULL,
    job_code ENUM('HOLD_EXPIRY','DORMANT_MARK','DORMANT_SUSPEND','RECON','STATEMENT') NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    processed_count BIGINT NOT NULL DEFAULT 0,
    detail VARCHAR(255) NULL,
    error_code VARCHAR(40) NULL,
    actor_email VARCHAR(100) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    UNIQUE KEY uq_eod_job_date (business_date, job_code),
    INDEX idx_eod_job_status (status, business_date),
    CHECK (processed_count >= 0)
) ENGINE=InnoDB;
