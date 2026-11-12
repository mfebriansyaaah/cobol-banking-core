-- Phase 2 slice: secret rotation tracking.

CREATE TABLE IF NOT EXISTS secret_rotation (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    secret_name VARCHAR(64) NOT NULL,
    next_rotation_at DATETIME NOT NULL,
    overlap_seconds INT NOT NULL DEFAULT 300,
    status ENUM('SCHEDULED','ROTATED','VERIFIED') NOT NULL DEFAULT 'SCHEDULED',
    scheduled_by VARCHAR(100) NOT NULL,
    scheduled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    rotated_by VARCHAR(100) NULL,
    rotated_at DATETIME NULL,
    verified_by VARCHAR(100) NULL,
    verified_at DATETIME NULL,
    INDEX idx_secret_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS secret_rotation_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    secret_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_secret_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
