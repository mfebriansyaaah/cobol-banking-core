-- D10 Data/Reporting: report builder lifecycle.

CREATE TABLE IF NOT EXISTS report_builder (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    report_ref VARCHAR(40) NOT NULL,
    report_name VARCHAR(100) NOT NULL,
    report_type VARCHAR(20) NOT NULL,
    run_count INT NOT NULL DEFAULT 0,
    row_count INT NOT NULL DEFAULT 0,
    status ENUM('OPEN','RUNNING','COMPLETED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    run_at DATETIME NULL,
    completed_at DATETIME NULL,
    closed_at DATETIME NULL,
    closure_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_report_builder_ref (report_ref),
    INDEX idx_report_builder_status (status, report_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_builder_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    report_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_report_builder_audit_actor (actor_email, created_at),
    INDEX idx_report_builder_audit_case (report_id, created_at)
) ENGINE=InnoDB;
