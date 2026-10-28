CREATE TABLE IF NOT EXISTS data_archive (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    archive_ref VARCHAR(40) NOT NULL,
    archive_name VARCHAR(100) NOT NULL,
    archive_type VARCHAR(20) NOT NULL,
    max_size_mb DECIMAL(18,4) NOT NULL DEFAULT 0,
    stored_size DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','PURGED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    archived_at DATETIME NULL,
    purged_at DATETIME NULL,
    purge_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_data_archive_ref (archive_ref),
    INDEX idx_data_archive_status (status, archive_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS data_archive_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    data_archive_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_DTA_audit_actor (actor_email, created_at),
    INDEX idx_DTA_audit_data_archive (data_archive_id, created_at)
) ENGINE=InnoDB;
