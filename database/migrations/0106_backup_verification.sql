-- Phase 2 slice: backup verification tracking.

CREATE TABLE IF NOT EXISTS backup_verification (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    backup_id BIGINT NOT NULL,
    checksum VARCHAR(128) NOT NULL,
    status ENUM('PENDING','VERIFIED','FAILED') NOT NULL DEFAULT 'PENDING',
    verified_by VARCHAR(100) NOT NULL,
    verified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_backup_verification_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS backup_verification_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_backup_verification_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
