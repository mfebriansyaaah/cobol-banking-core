-- Phase 1 Sprint 1 slice 14: audit analytics and import reconciliation.

CREATE TABLE IF NOT EXISTS audit_analytics_snapshot (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    snapshot_date DATE NOT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    event_count BIGINT NOT NULL DEFAULT 0,
    failure_count BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_audit_snapshot (snapshot_date, action, actor_email),
    CHECK (event_count >= 0 AND failure_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS import_recon_run (
    id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    row_count BIGINT NOT NULL DEFAULT 0,
    matched_count BIGINT NOT NULL DEFAULT 0,
    unmatched_count BIGINT NOT NULL DEFAULT 0,
    mismatch_count BIGINT NOT NULL DEFAULT 0,
    error_detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    CONSTRAINT fk_import_recon_batch FOREIGN KEY (batch_id)
        REFERENCES import_batch(id) ON DELETE CASCADE,
    INDEX idx_import_recon_status (status, started_at),
    CHECK (row_count >= 0 AND matched_count >= 0 AND unmatched_count >= 0 AND mismatch_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS import_recon_item (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    run_id INT NOT NULL,
    import_row_id INT NOT NULL,
    account_code VARCHAR(20) NOT NULL,
    debit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    credit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    matched_journal_id INT NULL,
    match_status ENUM('MATCHED','UNMATCHED','MISMATCH') NOT NULL,
    detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_import_recon_item_run FOREIGN KEY (run_id)
        REFERENCES import_recon_run(id) ON DELETE CASCADE,
    CONSTRAINT fk_import_recon_item_row FOREIGN KEY (import_row_id)
        REFERENCES import_row(id) ON DELETE CASCADE,
    CONSTRAINT fk_import_recon_item_journal FOREIGN KEY (matched_journal_id)
        REFERENCES gl_journal(id) ON DELETE SET NULL,
    UNIQUE KEY uq_import_recon_item (run_id, import_row_id),
    INDEX idx_import_recon_status (run_id, match_status)
) ENGINE=InnoDB;
