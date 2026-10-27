CREATE TABLE IF NOT EXISTS incident_postmortem (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    incident_ref VARCHAR(40) NOT NULL,
    title VARCHAR(100) NOT NULL,
    incident_type VARCHAR(20) NOT NULL,
    impact_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    reviewed_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','REVIEWED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    reviewed_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_incident_postmortem_ref (incident_ref),
    INDEX idx_incident_postmortem_status (status, incident_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS incident_postmortem_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    incident_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_incident_postmortem_audit_actor (actor_email, created_at),
    INDEX idx_incident_postmortem_audit_incident (incident_id, created_at)
) ENGINE=InnoDB;
