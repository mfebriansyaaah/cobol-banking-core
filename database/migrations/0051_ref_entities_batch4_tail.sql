-- Generated reference-data table for the 60k COBOL-net top-up.
CREATE TABLE IF NOT EXISTS ref_report_layout (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;
