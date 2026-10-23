-- Phase 2 slice: capacity planning tracking.

CREATE TABLE IF NOT EXISTS capacity_plan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    plan_name VARCHAR(100) NOT NULL,
    threshold VARCHAR(40) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    status ENUM('ACTIVE','RETIRED') NOT NULL DEFAULT 'ACTIVE',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_capacity_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS capacity_breach (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    plan_id BIGINT NOT NULL,
    observed VARCHAR(40) NOT NULL,
    breached_at DATETIME NOT NULL,
    recorded_by VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS capacity_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    plan_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_capacity_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
