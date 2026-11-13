-- Phase 1 Sprint 1 slice 12: schedule run history and statement reconciliation.

CREATE TABLE IF NOT EXISTS report_schedule_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    schedule_id INT NOT NULL,
    report_run_id INT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    period_from DATE NULL,
    period_to DATE NULL,
    currency_code CHAR(3) NULL,
    output_format ENUM('CSV','FIXED','JSON') NULL,
    error_detail VARCHAR(255) NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    CONSTRAINT fk_schedule_run_schedule FOREIGN KEY (schedule_id)
        REFERENCES report_schedule(id) ON DELETE CASCADE,
    CONSTRAINT fk_schedule_run_report FOREIGN KEY (report_run_id)
        REFERENCES report_run(id) ON DELETE SET NULL,
    INDEX idx_schedule_run_status (status, started_at),
    INDEX idx_schedule_run_schedule (schedule_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_recon_run (
    id INT AUTO_INCREMENT PRIMARY KEY,
    statement_run_id INT NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    line_count BIGINT NOT NULL DEFAULT 0,
    matched_count BIGINT NOT NULL DEFAULT 0,
    unmatched_count BIGINT NOT NULL DEFAULT 0,
    mismatch_count BIGINT NOT NULL DEFAULT 0,
    error_detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    CONSTRAINT fk_stmt_recon_run_statement FOREIGN KEY (statement_run_id)
        REFERENCES statement_run(id) ON DELETE CASCADE,
    INDEX idx_stmt_recon_status (status, started_at),
    CHECK (line_count >= 0 AND matched_count >= 0 AND unmatched_count >= 0 AND mismatch_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_recon_item (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    run_id INT NOT NULL,
    statement_line_id BIGINT NOT NULL,
    account_id INT NULL,
    txn_ref VARCHAR(50) NOT NULL,
    posting_date DATE NOT NULL,
    amount DECIMAL(30,10) NOT NULL,
    matched_ledger_id BIGINT NULL,
    match_status ENUM('MATCHED','UNMATCHED','MISMATCH') NOT NULL,
    detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_stmt_item_run FOREIGN KEY (run_id)
        REFERENCES statement_recon_run(id) ON DELETE CASCADE,
    CONSTRAINT fk_stmt_item_line FOREIGN KEY (statement_line_id)
        REFERENCES statement_archive_line(id) ON DELETE CASCADE,
    CONSTRAINT fk_stmt_item_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id) ON DELETE SET NULL,
    CONSTRAINT fk_stmt_item_ledger FOREIGN KEY (matched_ledger_id)
        REFERENCES ledger(ledger_id) ON DELETE SET NULL,
    UNIQUE KEY uq_stmt_item_line (run_id, statement_line_id),
    INDEX idx_stmt_item_status (run_id, match_status)
) ENGINE=InnoDB;
