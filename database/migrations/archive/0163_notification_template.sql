CREATE TABLE IF NOT EXISTS ntf_template_config (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    template_ref VARCHAR(40) NOT NULL,
    template_name VARCHAR(100) NOT NULL,
    template_type VARCHAR(20) NOT NULL,
    max_deliveries DECIMAL(18,4) NOT NULL DEFAULT 0,
    sent_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','INACTIVE','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    deactivated_at DATETIME NULL,
    deactivate_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_ntf_template_config_ref (template_ref),
    INDEX idx_ntf_template_config_status (status, template_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS ntf_template_config_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    ntf_template_config_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ntf_audit_actor (actor_email, created_at),
    INDEX idx_ntf_audit_config (ntf_template_config_id, created_at)
) ENGINE=InnoDB;
