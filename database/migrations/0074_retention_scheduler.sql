-- Phase 1 Sprint 1 slice 19: compliance retention and report scheduling.

CREATE TABLE IF NOT EXISTS compliance_retention_policy (
    policy_code VARCHAR(40) PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    retention_days INT NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (retention_days BETWEEN 1 AND 3650)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compliance_retention_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    policy_code VARCHAR(40) NOT NULL,
    archived_count BIGINT NOT NULL DEFAULT 0,
    purged_count BIGINT NOT NULL DEFAULT 0,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    executed_by VARCHAR(100) NOT NULL,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_retention_run_policy FOREIGN KEY (policy_code)
        REFERENCES compliance_retention_policy(policy_code) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compliance_retention_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    policy_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_retention_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS report_scheduler_run;
DROP TABLE IF EXISTS report_scheduler_audit;
DROP TABLE IF EXISTS report_scheduler;
CREATE TABLE IF NOT EXISTS report_scheduler (
    schedule_code VARCHAR(40) PRIMARY KEY,
    report_type VARCHAR(40) NOT NULL,
    frequency ENUM('DAILY','WEEKLY','MONTHLY') NOT NULL,
    next_run_at DATETIME NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_scheduler_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    schedule_code VARCHAR(40) NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    row_count BIGINT NOT NULL DEFAULT 0,
    error_detail VARCHAR(255) NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    CONSTRAINT fk_schedule_run FOREIGN KEY (schedule_code)
        REFERENCES report_scheduler(schedule_code) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_scheduler_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    schedule_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_schedule_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
