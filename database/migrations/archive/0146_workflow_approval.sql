CREATE TABLE IF NOT EXISTS workflow_approval (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    workflow_ref VARCHAR(40) NOT NULL,
    entity_name VARCHAR(100) NOT NULL,
    entity_type VARCHAR(20) NOT NULL,
    priority DECIMAL(18,4) NOT NULL DEFAULT 0,
    decision_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','DECIDED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    decided_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_workflow_approval_ref (workflow_ref),
    INDEX idx_workflow_approval_status (status, entity_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS workflow_approval_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    workflow_approval_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_workflow_approval_audit_actor (actor_email, created_at),
    INDEX idx_workflow_approval_audit_workflow_approval (workflow_approval_id, created_at)
) ENGINE=InnoDB;
