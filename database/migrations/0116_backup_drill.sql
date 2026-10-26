-- D9 IT Ops: backup drill lifecycle.

CREATE TABLE IF NOT EXISTS backup_drill (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    drill_ref VARCHAR(40) NOT NULL,
    target_table VARCHAR(100) NOT NULL,
    backup_type VARCHAR(20) NOT NULL,
    run_count INT NOT NULL DEFAULT 0,
    verified_count INT NOT NULL DEFAULT 0,
    status ENUM('OPEN','RUNNING','VERIFIED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    run_at DATETIME NULL,
    verified_at DATETIME NULL,
    closed_at DATETIME NULL,
    closure_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_backup_drill_ref (drill_ref),
    INDEX idx_backup_drill_status (status, backup_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS backup_drill_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    drill_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_backup_drill_audit_actor (actor_email, created_at),
    INDEX idx_backup_drill_audit_case (drill_id, created_at)
) ENGINE=InnoDB;
