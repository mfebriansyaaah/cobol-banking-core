CREATE TABLE IF NOT EXISTS api_management (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    api_ref VARCHAR(40) NOT NULL,
    api_name VARCHAR(100) NOT NULL,
    api_type VARCHAR(20) NOT NULL,
    rate_limit DECIMAL(18,4) NOT NULL DEFAULT 0,
    call_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','INACTIVE','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    deactivated_at DATETIME NULL,
    deactivate_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_api_management_ref (api_ref),
    INDEX idx_api_management_status (status, api_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS api_management_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    api_management_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_APM_audit_actor (actor_email, created_at),
    INDEX idx_APM_audit_api_management (api_management_id, created_at)
) ENGINE=InnoDB;
