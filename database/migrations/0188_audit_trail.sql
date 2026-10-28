CREATE TABLE IF NOT EXISTS adt_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    audit_ref VARCHAR(40) NOT NULL,
    audit_name VARCHAR(100) NOT NULL,
    audit_type VARCHAR(20) NOT NULL,
    max_entries DECIMAL(18,4) NOT NULL DEFAULT 0,
    entry_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_adt_log_ref (audit_ref),
    INDEX idx_adt_log_status (status, audit_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS adt_log_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    adt_log_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ADT_audit_actor (actor_email, created_at),
    INDEX idx_ADT_audit_adt_log (adt_log_id, created_at)
) ENGINE=InnoDB;
