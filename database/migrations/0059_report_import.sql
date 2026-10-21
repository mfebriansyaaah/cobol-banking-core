-- Phase 1 Sprint 1 slice 3: report engine and import/export foundation.

CREATE TABLE IF NOT EXISTS report_template (
    id INT AUTO_INCREMENT PRIMARY KEY,
    template_code VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    report_type ENUM('TRIAL_BALANCE','STATEMENT','RECONCILIATION','CUSTOM') NOT NULL,
    output_format ENUM('CSV','FIXED','JSON') NOT NULL DEFAULT 'CSV',
    title VARCHAR(100) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_template_column (
    id INT AUTO_INCREMENT PRIMARY KEY,
    template_id INT NOT NULL,
    ordinal INT NOT NULL,
    header VARCHAR(100) NOT NULL,
    source_field VARCHAR(100) NOT NULL,
    width INT NOT NULL DEFAULT 20,
    align ENUM('LEFT','RIGHT','CENTER') NOT NULL DEFAULT 'LEFT',
    column_format ENUM('TEXT','AMOUNT','DATE','INTEGER') NOT NULL DEFAULT 'TEXT',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_report_column_ordinal (template_id, ordinal),
    CONSTRAINT fk_report_column_template FOREIGN KEY (template_id)
        REFERENCES report_template(id) ON DELETE CASCADE,
    CHECK (ordinal BETWEEN 1 AND 50),
    CHECK (width BETWEEN 1 AND 80)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_run (
    id INT AUTO_INCREMENT PRIMARY KEY,
    template_id INT NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    parameters VARCHAR(255) NOT NULL,
    row_count BIGINT NOT NULL DEFAULT 0,
    total_debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    total_credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    checksum VARCHAR(64) NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    version INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_report_run_status (status, started_at),
    INDEX idx_report_run_template (template_id, started_at),
    CONSTRAINT fk_report_run_template FOREIGN KEY (template_id)
        REFERENCES report_template(id),
    CHECK (row_count >= 0),
    CHECK (total_debit >= 0 AND total_credit >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_run_row (
    id INT AUTO_INCREMENT PRIMARY KEY,
    run_id INT NOT NULL,
    ordinal INT NOT NULL,
    row_data VARCHAR(500) NOT NULL,
    debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_report_row_ordinal (run_id, ordinal),
    CONSTRAINT fk_report_row_run FOREIGN KEY (run_id)
        REFERENCES report_run(id) ON DELETE CASCADE,
    CHECK (ordinal BETWEEN 1 AND 99999),
    CHECK (debit >= 0 AND credit >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    template_code VARCHAR(40) NULL,
    run_id INT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_report_audit_actor (actor_email, created_at),
    INDEX idx_report_audit_run (run_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS import_batch (
    id INT AUTO_INCREMENT PRIMARY KEY,
    batch_code VARCHAR(40) NOT NULL UNIQUE,
    source_name VARCHAR(100) NOT NULL,
    import_type ENUM('LEDGER','ACCOUNTS','REFERENCE','PAYMENTS') NOT NULL,
    status ENUM('STAGED','VALIDATING','VALIDATED','COMPLETED','FAILED') NOT NULL DEFAULT 'STAGED',
    total_rows BIGINT NOT NULL DEFAULT 0,
    valid_rows BIGINT NOT NULL DEFAULT 0,
    invalid_rows BIGINT NOT NULL DEFAULT 0,
    posted_rows BIGINT NOT NULL DEFAULT 0,
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    version INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_import_batch_status (status, created_at),
    INDEX idx_import_batch_type (import_type, created_at),
    CHECK (total_rows >= 0 AND valid_rows >= 0 AND invalid_rows >= 0 AND posted_rows >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS import_row (
    id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NOT NULL,
    row_no INT NOT NULL,
    raw_data VARCHAR(500) NOT NULL,
    status ENUM('STAGED','VALID','INVALID','POSTED','SKIPPED') NOT NULL DEFAULT 'STAGED',
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_import_row_no (batch_id, row_no),
    CONSTRAINT fk_import_row_batch FOREIGN KEY (batch_id)
        REFERENCES import_batch(id) ON DELETE CASCADE,
    CHECK (row_no BETWEEN 1 AND 99999)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS import_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    batch_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_import_audit_actor (actor_email, created_at),
    INDEX idx_import_audit_batch (batch_code)
) ENGINE=InnoDB;
