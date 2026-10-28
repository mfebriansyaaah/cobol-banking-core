CREATE TABLE IF NOT EXISTS sla_tracker (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    sla_ref VARCHAR(40) NOT NULL,
    sla_name VARCHAR(100) NOT NULL,
    sla_type VARCHAR(20) NOT NULL,
    target_response DECIMAL(18,4) NOT NULL DEFAULT 0,
    actual_response DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_sla_tracker_ref (sla_ref),
    INDEX idx_sla_tracker_status (status, sla_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS sla_tracker_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    sla_tracker_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_sla_audit_actor (actor_email, created_at),
    INDEX idx_sla_audit_tracker (sla_tracker_id, created_at)
) ENGINE=InnoDB;
