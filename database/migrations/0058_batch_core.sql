-- Phase 1 Sprint 1 slice 2: batch/EOD foundation.
-- Job definitions, ordered steps, runs, run steps, control totals, and audit.

CREATE TABLE IF NOT EXISTS batch_job (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job_code VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    job_type ENUM('EOD','INTRADAY','REPORT','CLEANUP') NOT NULL,
    frequency ENUM('MANUAL','DAILY','WEEKLY','MONTHLY') NOT NULL DEFAULT 'MANUAL',
    schedule_time TIME NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    max_retries INT NOT NULL DEFAULT 3,
    timeout_seconds INT NOT NULL DEFAULT 3600,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (max_retries BETWEEN 0 AND 20),
    CHECK (timeout_seconds BETWEEN 1 AND 86400)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS batch_job_step (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job_id INT NOT NULL,
    step_no INT NOT NULL,
    step_code VARCHAR(40) NOT NULL,
    step_name VARCHAR(100) NOT NULL,
    max_retries INT NOT NULL DEFAULT 3,
    is_required BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_batch_job_step_no (job_id, step_no),
    UNIQUE KEY uq_batch_job_step_code (job_id, step_code),
    CONSTRAINT fk_batch_job_step_job FOREIGN KEY (job_id)
        REFERENCES batch_job(id) ON DELETE CASCADE,
    CHECK (step_no BETWEEN 1 AND 99),
    CHECK (max_retries BETWEEN 0 AND 20)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS batch_run (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job_id INT NOT NULL,
    business_date DATE NOT NULL,
    status ENUM('RUNNING','PAUSED','COMPLETED','FAILED','CANCELLED') NOT NULL DEFAULT 'RUNNING',
    attempt INT NOT NULL DEFAULT 1,
    checkpoint_key VARCHAR(100) NULL,
    checkpoint_value VARCHAR(100) NULL,
    processed_count BIGINT NOT NULL DEFAULT 0,
    success_count BIGINT NOT NULL DEFAULT 0,
    failed_count BIGINT NOT NULL DEFAULT 0,
    control_debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    control_credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    locked_by VARCHAR(100) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    version INT NOT NULL DEFAULT 0,
    UNIQUE KEY uq_batch_run_attempt (job_id, business_date, attempt),
    INDEX idx_batch_run_status (status, business_date),
    INDEX idx_batch_run_job (job_id, business_date),
    CONSTRAINT fk_batch_run_job FOREIGN KEY (job_id)
        REFERENCES batch_job(id),
    CHECK (attempt BETWEEN 1 AND 999),
    CHECK (processed_count >= 0 AND success_count >= 0 AND failed_count >= 0),
    CHECK (control_debit >= 0 AND control_credit >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS batch_run_step (
    id INT AUTO_INCREMENT PRIMARY KEY,
    run_id INT NOT NULL,
    step_no INT NOT NULL,
    step_code VARCHAR(40) NOT NULL,
    status ENUM('PENDING','RUNNING','COMPLETED','FAILED','SKIPPED') NOT NULL DEFAULT 'PENDING',
    attempt INT NOT NULL DEFAULT 0,
    processed_count BIGINT NOT NULL DEFAULT 0,
    success_count BIGINT NOT NULL DEFAULT 0,
    failed_count BIGINT NOT NULL DEFAULT 0,
    control_debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    control_credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    started_at DATETIME NULL,
    finished_at DATETIME NULL,
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_batch_run_step (run_id, step_no),
    CONSTRAINT fk_batch_run_step_run FOREIGN KEY (run_id)
        REFERENCES batch_run(id) ON DELETE CASCADE,
    CHECK (step_no BETWEEN 1 AND 99),
    CHECK (attempt BETWEEN 0 AND 999),
    CHECK (processed_count >= 0 AND success_count >= 0 AND failed_count >= 0),
    CHECK (control_debit >= 0 AND control_credit >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS batch_control_total (
    id INT AUTO_INCREMENT PRIMARY KEY,
    run_id INT NOT NULL,
    total_code VARCHAR(40) NOT NULL,
    expected_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    actual_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    variance DECIMAL(30,10) NOT NULL DEFAULT 0,
    status ENUM('MATCH','VARIANCE') NOT NULL DEFAULT 'MATCH',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_batch_control_total (run_id, total_code),
    CONSTRAINT fk_batch_control_run FOREIGN KEY (run_id)
        REFERENCES batch_run(id) ON DELETE CASCADE,
    CHECK (expected_amount >= 0 AND actual_amount >= 0 AND variance >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS batch_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id INT NULL,
    job_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_batch_audit_actor (actor_email, created_at),
    INDEX idx_batch_audit_run (run_id)
) ENGINE=InnoDB;
