-- Phase 1 Sprint 1 slice 10: reconciliation auto-assignment and operations alerts.

CREATE TABLE IF NOT EXISTS recon_assignment_rule (
    rule_code VARCHAR(40) PRIMARY KEY,
    owner_email VARCHAR(100) NOT NULL,
    status_filter ENUM('ANY','OPEN','ACKNOWLEDGED') NOT NULL DEFAULT 'ANY',
    min_age_hours INT NOT NULL DEFAULT 0,
    priority INT NOT NULL DEFAULT 100,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_recon_rule_match (enabled, status_filter, min_age_hours, priority),
    CHECK (min_age_hours BETWEEN 0 AND 8760),
    CHECK (priority BETWEEN 1 AND 999)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS recon_assignment (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    finding_id BIGINT NOT NULL,
    from_owner VARCHAR(100) NULL,
    to_owner VARCHAR(100) NOT NULL,
    rule_code VARCHAR(40) NULL,
    assigned_by VARCHAR(100) NOT NULL,
    note VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_recon_assignment_finding FOREIGN KEY (finding_id)
        REFERENCES reconciliation_findings(finding_id) ON DELETE CASCADE,
    INDEX idx_recon_assignment_finding (finding_id, id),
    INDEX idx_recon_assignment_owner (to_owner, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ops_alert (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alert_type VARCHAR(32) NOT NULL,
    severity ENUM('INFO','WARNING','CRITICAL') NOT NULL DEFAULT 'WARNING',
    source_key VARCHAR(120) NOT NULL,
    title VARCHAR(160) NOT NULL,
    detail VARCHAR(255) NOT NULL DEFAULT '',
    state ENUM('OPEN','ACKNOWLEDGED','RESOLVED') NOT NULL DEFAULT 'OPEN',
    owner_email VARCHAR(100) NULL,
    acknowledged_at DATETIME NULL,
    resolved_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_ops_alert_source (source_key),
    INDEX idx_ops_alert_state (state, severity, created_at),
    INDEX idx_ops_alert_type (alert_type, state)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ops_alert_event (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alert_id BIGINT NOT NULL,
    event ENUM('RAISED','ACKNOWLEDGED','RESOLVED','NOTE','REOPENED') NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    note VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ops_alert_event FOREIGN KEY (alert_id)
        REFERENCES ops_alert(id) ON DELETE CASCADE,
    INDEX idx_ops_alert_event (alert_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ops_alert_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    alert_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ops_alert_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
