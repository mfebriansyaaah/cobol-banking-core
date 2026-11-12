-- Phase 2 slice: data retention tracking.

CREATE TABLE IF NOT EXISTS data_retention_policy (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    policy_name VARCHAR(64) NOT NULL,
    retention_days INT NOT NULL,
    status ENUM('ACTIVE','RETIRED') NOT NULL DEFAULT 'ACTIVE',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_data_retention_policy (policy_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS data_retention_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    policy_id BIGINT NOT NULL,
    purged_count BIGINT NOT NULL DEFAULT 0,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'COMPLETED',
    run_by VARCHAR(100) NOT NULL,
    run_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS data_retention_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    policy_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_data_retention_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
