-- Phase 2 slice: incident and change control cores.

CREATE TABLE IF NOT EXISTS incident (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    severity ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT NULL DEFAULT 'MEDIUM',
    source VARCHAR(100) NOT NULL,
    status ENUM('OPEN','ACKNOWLEDGED','RESOLVED','CLOSED') NOT NULL DEFAULT 'OPEN',
    assignee VARCHAR(100) NULL,
    resolution VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at DATETIME NULL,
    closed_at DATETIME NULL,
    INDEX idx_incident_status (status, severity)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS incident_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    incident_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_incident_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS change_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    change_type VARCHAR(40) NOT NULL,
    risk ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    status ENUM('REQUESTED','APPROVED','REJECTED','DEPLOYED','ROLLEDBACK') NOT NULL DEFAULT 'REQUESTED',
    requested_by VARCHAR(100) NOT NULL,
    approved_by VARCHAR(100) NULL,
    rejected_by VARCHAR(100) NULL,
    deployed_at DATETIME NULL,
    rolled_back_at DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_change_status (status, risk)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS change_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    change_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_change_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
