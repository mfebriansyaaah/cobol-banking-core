CREATE TABLE IF NOT EXISTS access_control (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    access_ref VARCHAR(40) NOT NULL,
    resource_name VARCHAR(100) NOT NULL,
    access_type VARCHAR(20) NOT NULL,
    max_access DECIMAL(18,4) NOT NULL DEFAULT 0,
    access_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','REVOKED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    granted_at DATETIME NULL,
    revoked_at DATETIME NULL,
    revoke_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_access_control_ref (access_ref),
    INDEX idx_access_control_status (status, access_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS access_control_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    access_control_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_AXC_audit_actor (actor_email, created_at),
    INDEX idx_AXC_audit_access_control (access_control_id, created_at)
) ENGINE=InnoDB;
