CREATE TABLE IF NOT EXISTS case_management (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_ref VARCHAR(40) NOT NULL,
    case_title VARCHAR(100) NOT NULL,
    case_type VARCHAR(20) NOT NULL,
    severity DECIMAL(18,4) NOT NULL DEFAULT 0,
    progress DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','RESOLVED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    assigned_at DATETIME NULL,
    resolved_at DATETIME NULL,
    resolution VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_case_management_ref (case_ref),
    INDEX idx_case_management_status (status, case_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS case_management_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_management_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_case_management_audit_actor (actor_email, created_at),
    INDEX idx_case_management_audit_case_management (case_management_id, created_at)
) ENGINE=InnoDB;
