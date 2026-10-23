-- Phase 2 slice: disaster recovery tracking.

CREATE TABLE IF NOT EXISTS dr_plan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    plan_name VARCHAR(100) NOT NULL,
    rto_minutes INT NOT NULL,
    rpo_minutes INT NOT NULL,
    status ENUM('ACTIVE','VERIFIED') NOT NULL DEFAULT 'ACTIVE',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verified_at DATETIME NULL,
    INDEX idx_dr_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dr_test (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    plan_id BIGINT NOT NULL,
    outcome VARCHAR(40) NOT NULL,
    tested_by VARCHAR(100) NOT NULL,
    tested_at DATETIME NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dr_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    plan_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_dr_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
