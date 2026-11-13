CREATE TABLE IF NOT EXISTS backup_management (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    backup_ref VARCHAR(40) NOT NULL,
    backup_name VARCHAR(100) NOT NULL,
    backup_type VARCHAR(20) NOT NULL,
    max_backups DECIMAL(18,4) NOT NULL DEFAULT 0,
    completed_backups DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','COMPLETED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    scheduled_at DATETIME NULL,
    completed_at DATETIME NULL,
    complete_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_backup_management_ref (backup_ref),
    INDEX idx_backup_management_status (status, backup_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS backup_management_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    backup_management_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_BUM_audit_actor (actor_email, created_at),
    INDEX idx_BUM_audit_backup_management (backup_management_id, created_at)
) ENGINE=InnoDB;
