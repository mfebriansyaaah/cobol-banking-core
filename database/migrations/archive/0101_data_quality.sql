-- Phase 2 slice: data quality tracking.

CREATE TABLE IF NOT EXISTS data_quality_rule (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rule_name VARCHAR(64) NOT NULL,
    severity ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    status ENUM('ACTIVE','RETIRED') NOT NULL DEFAULT 'ACTIVE',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_data_quality_rule (rule_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS data_quality_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rule_id BIGINT NOT NULL,
    findings BIGINT NOT NULL DEFAULT 0,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'COMPLETED',
    run_by VARCHAR(100) NOT NULL,
    run_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS data_quality_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    rule_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_data_quality_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
