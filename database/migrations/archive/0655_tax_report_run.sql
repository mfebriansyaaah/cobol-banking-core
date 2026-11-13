-- PR-401: Tax Withholding — report runs.
-- tax_report (baseline) is left untouched for compat.

CREATE TABLE IF NOT EXISTS tax_report_run (
    run_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    period VARCHAR(20) NOT NULL,
    tax_type VARCHAR(20) NOT NULL,
    total_base DECIMAL(18,4) NOT NULL DEFAULT 0,
    total_tax DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'IDR',
    status ENUM('DRAFT','FILED','FAILED') NOT NULL DEFAULT 'DRAFT',
    submitted_at DATETIME NULL,
    evidence_ref VARCHAR(100) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_tax_report_run (period, tax_type, currency),
    INDEX idx_tax_report_run_status (status, period)
) ENGINE=InnoDB;
