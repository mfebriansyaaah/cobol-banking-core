CREATE TABLE IF NOT EXISTS permission_set (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    perm_ref VARCHAR(40) NOT NULL,
    perm_name VARCHAR(100) NOT NULL,
    perm_type VARCHAR(20) NOT NULL,
    max_grants DECIMAL(18,4) NOT NULL DEFAULT 0,
    grant_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','REVOKED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    revoked_at DATETIME NULL,
    revoke_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_permission_set_ref (perm_ref),
    INDEX idx_permission_set_status (status, perm_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS permission_set_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    permission_set_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_PMS_audit_actor (actor_email, created_at),
    INDEX idx_PMS_audit_permission_set (permission_set_id, created_at)
) ENGINE=InnoDB;
