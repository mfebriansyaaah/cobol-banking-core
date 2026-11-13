-- Phase 2 slice: SLA tracking.

CREATE TABLE IF NOT EXISTS sla_definition (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    sla_name VARCHAR(64) NOT NULL,
    target_pct DECIMAL(5,2) NOT NULL,
    status ENUM('ACTIVE','RETIRED') NOT NULL DEFAULT 'ACTIVE',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_sla_name (sla_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sla_breach (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    sla_id BIGINT NOT NULL,
    observed VARCHAR(40) NOT NULL,
    breached_at DATETIME NOT NULL,
    recorded_by VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sla_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    sla_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_sla_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
