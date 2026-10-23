-- Phase 2 slice: compliance audit tracking.

CREATE TABLE IF NOT EXISTS compliance_finding (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    severity ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT NULL DEFAULT 'MEDIUM',
    status ENUM('OPEN','CLOSED') NOT NULL DEFAULT 'OPEN',
    raised_by VARCHAR(100) NOT NULL,
    raised_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    closed_at DATETIME NULL,
    INDEX idx_compliance_finding_status (status, severity)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compliance_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    finding_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_compliance_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
