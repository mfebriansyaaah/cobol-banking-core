CREATE TABLE IF NOT EXISTS rpt_schedule_config (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    schedule_ref VARCHAR(40) NOT NULL,
    schedule_name VARCHAR(100) NOT NULL,
    schedule_type VARCHAR(20) NOT NULL,
    max_instances DECIMAL(18,4) NOT NULL DEFAULT 0,
    run_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','INACTIVE','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    deactivated_at DATETIME NULL,
    deactivate_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_rpt_schedule_config_ref (schedule_ref),
    INDEX idx_rpt_schedule_config_status (status, schedule_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS rpt_schedule_config_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rpt_schedule_config_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_rsc_audit_actor (actor_email, created_at),
    INDEX idx_rsc_audit_config (rpt_schedule_config_id, created_at)
) ENGINE=InnoDB;
