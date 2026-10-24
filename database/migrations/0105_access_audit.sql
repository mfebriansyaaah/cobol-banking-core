-- Phase 2 slice: access audit tracking.

CREATE TABLE IF NOT EXISTS access_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_type VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    subject_email VARCHAR(100) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_access_audit_actor (actor_email, created_at),
    INDEX idx_access_audit_event (event_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS access_audit_entry (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    audit_id BIGINT NOT NULL,
    event VARCHAR(40) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
