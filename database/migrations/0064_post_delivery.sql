-- Phase 1 Sprint 1 slice 8: import posting and report delivery.

ALTER TABLE import_row
    ADD COLUMN IF NOT EXISTS parsed_account VARCHAR(20) NULL,
    ADD COLUMN IF NOT EXISTS debit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS credit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    ADD INDEX IF NOT EXISTS idx_import_row_parsed (batch_id, parsed_account);

CREATE TABLE IF NOT EXISTS import_posting (
    id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NOT NULL,
    journal_id INT NOT NULL,
    posted_rows BIGINT NOT NULL DEFAULT 0,
    total_debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    total_credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    status ENUM('POSTED','REVERSED') NOT NULL DEFAULT 'POSTED',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_import_posting_batch (batch_id),
    CONSTRAINT fk_import_posting_batch FOREIGN KEY (batch_id)
        REFERENCES import_batch(id) ON DELETE CASCADE,
    CONSTRAINT fk_import_posting_journal FOREIGN KEY (journal_id)
        REFERENCES gl_journal(id),
    CHECK (posted_rows >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_layout (
    id INT AUTO_INCREMENT PRIMARY KEY,
    template_id INT NOT NULL,
    page_width INT NOT NULL DEFAULT 132,
    page_length INT NOT NULL DEFAULT 66,
    header_text VARCHAR(100) NOT NULL DEFAULT '',
    footer_text VARCHAR(100) NOT NULL DEFAULT '',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_report_layout_template (template_id),
    CONSTRAINT fk_report_layout_template FOREIGN KEY (template_id)
        REFERENCES report_template(id) ON DELETE CASCADE,
    CHECK (page_width BETWEEN 40 AND 240),
    CHECK (page_length BETWEEN 10 AND 200)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_schedule (
    id INT AUTO_INCREMENT PRIMARY KEY,
    template_code VARCHAR(40) NOT NULL,
    frequency ENUM('DAILY','WEEKLY','MONTHLY') NOT NULL,
    schedule_time TIME NOT NULL,
    output_format ENUM('CSV','FIXED','JSON') NOT NULL DEFAULT 'CSV',
    currency_code CHAR(3) NOT NULL DEFAULT 'IDR',
    recipient VARCHAR(100) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    last_run_at DATETIME NULL,
    next_run_date DATE NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_report_schedule_due (enabled, next_run_date),
    CHECK (recipient LIKE '%@%')
) ENGINE=InnoDB;
