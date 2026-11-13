-- Phase 2 slice: report audit tracking.

CREATE TABLE IF NOT EXISTS report_execution_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    report_name VARCHAR(64) NOT NULL,
    duration_ms INT NOT NULL DEFAULT 0,
    status ENUM('OK','FAILED') NOT NULL DEFAULT 'OK',
    recorded_by VARCHAR(100) NOT NULL,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_report_execution_audit_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_execution_audit_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_report_execution_audit_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
