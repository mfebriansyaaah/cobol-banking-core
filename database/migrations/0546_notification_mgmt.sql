CREATE TABLE IF NOT EXISTS notification_mgmt (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    ntf_ref VARCHAR(40) NOT NULL,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL,
    budget_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    spent_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    closed_at DATETIME NULL,
    closure_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_notification_mgmt_ref (ntf_ref),
    INDEX idx_notification_mgmt_status (status, type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS notification_mgmt_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    notification_mgmt_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_NTFC_audit_actor (actor_email, created_at),
    INDEX idx_NTFC_audit_notification_mgmt (notification_mgmt_id, created_at)
) ENGINE=InnoDB;
