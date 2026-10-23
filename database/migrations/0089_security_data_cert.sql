-- Phase 3 slice: security, data governance, and certification.
-- Legal hold, key rotation, DSAR, and retention job cores.

CREATE TABLE IF NOT EXISTS legal_hold (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    subject_email VARCHAR(100) NOT NULL,
    case_ref VARCHAR(64) NOT NULL,
    scope ENUM('USER','ACCOUNT','AUDIT','LEDGER','GENERAL') NOT NULL DEFAULT 'GENERAL',
    status ENUM('ACTIVE','RELEASED') NOT NULL DEFAULT 'ACTIVE',
    reason VARCHAR(255) NULL,
    placed_by VARCHAR(100) NOT NULL,
    placed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    released_by VARCHAR(100) NULL,
    released_at DATETIME NULL,
    UNIQUE KEY uq_legal_hold_case (case_ref),
    INDEX idx_legal_hold_subject (subject_email, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS legal_hold_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    hold_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_legal_hold_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS key_rotation_plan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(64) NOT NULL,
    current_version INT NOT NULL DEFAULT 1,
    status ENUM('SCHEDULED','ACTIVE','COMPLETED','CANCELLED') NOT NULL DEFAULT 'SCHEDULED',
    overlap_seconds INT NOT NULL DEFAULT 300,
    next_rotation_at DATETIME NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    UNIQUE KEY uq_key_rotation_key (key_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS key_rotation_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    plan_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_key_rotation_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dsar_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    subject_email VARCHAR(100) NOT NULL,
    request_type ENUM('EXPORT','ERASE') NOT NULL DEFAULT 'EXPORT',
    status ENUM('RECEIVED','IN_PROGRESS','FULFILLED','REJECTED') NOT NULL DEFAULT 'RECEIVED',
    scope VARCHAR(64) NOT NULL DEFAULT 'PROFILE',
    detail VARCHAR(255) NULL,
    received_by VARCHAR(100) NOT NULL,
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(100) NULL,
    decided_at DATETIME NULL,
    INDEX idx_dsar_subject (subject_email, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dsar_request_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    request_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_dsar_request_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS retention_job_policy (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    data_class VARCHAR(40) NOT NULL,
    retention_days INT NOT NULL,
    enabled TINYINT NOT NULL DEFAULT 1,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_retention_job_class (data_class)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS retention_job_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    data_class VARCHAR(40) NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    cutoff_at DATETIME NOT NULL,
    archived_count BIGINT NOT NULL DEFAULT 0,
    deleted_count BIGINT NOT NULL DEFAULT 0,
    skipped_count BIGINT NOT NULL DEFAULT 0,
    detail VARCHAR(255) NULL,
    executed_by VARCHAR(100) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS retention_job_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_retention_job_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
