CREATE TABLE IF NOT EXISTS compliance_calendar (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    calendar_ref VARCHAR(40) NOT NULL,
    event_name VARCHAR(100) NOT NULL,
    event_type VARCHAR(20) NOT NULL,
    max_events DECIMAL(18,4) NOT NULL DEFAULT 0,
    completed_events DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_compliance_calendar_ref (calendar_ref),
    INDEX idx_compliance_calendar_status (status, event_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS compliance_calendar_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    compliance_calendar_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ccl_audit_actor (actor_email, created_at),
    INDEX idx_ccl_audit_calendar (compliance_calendar_id, created_at)
) ENGINE=InnoDB;
