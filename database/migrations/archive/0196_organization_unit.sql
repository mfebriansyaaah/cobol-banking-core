CREATE TABLE IF NOT EXISTS organization_unit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    org_ref VARCHAR(40) NOT NULL,
    org_name VARCHAR(100) NOT NULL,
    org_type VARCHAR(20) NOT NULL,
    max_members DECIMAL(18,4) NOT NULL DEFAULT 0,
    member_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_organization_unit_ref (org_ref),
    INDEX idx_organization_unit_status (status, org_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS organization_unit_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    organization_unit_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ORG_audit_actor (actor_email, created_at),
    INDEX idx_ORG_audit_organization_unit (organization_unit_id, created_at)
) ENGINE=InnoDB;
