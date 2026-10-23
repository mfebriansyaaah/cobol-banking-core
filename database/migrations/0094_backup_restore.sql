-- Phase 2 slice: backup and restore tracking.

CREATE TABLE IF NOT EXISTS backup_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    backup_type VARCHAR(40) NOT NULL,
    target VARCHAR(100) NOT NULL,
    status ENUM('RUNNING','VERIFIED','RESTORED','FAILED') NOT NULL DEFAULT 'RUNNING',
    started_by VARCHAR(100) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verified_by VARCHAR(100) NULL,
    verified_at DATETIME NULL,
    restored_by VARCHAR(100) NULL,
    restored_at DATETIME NULL,
    INDEX idx_backup_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS backup_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    backup_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_backup_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
