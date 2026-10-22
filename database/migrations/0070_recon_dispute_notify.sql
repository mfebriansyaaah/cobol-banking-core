-- Phase 1 Sprint 1 slice 15: reconciliation exceptions and dispute notifications.

CREATE TABLE IF NOT EXISTS recon_exception (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    finding_id BIGINT NULL,
    exception_code VARCHAR(40) NOT NULL,
    priority ENUM('LOW','NORMAL','HIGH','URGENT') NOT NULL DEFAULT 'NORMAL',
    owner_email VARCHAR(100) NULL,
    state ENUM('OPEN','ACKNOWLEDGED','IN_PROGRESS','RESOLVED','REJECTED','CLOSED') NOT NULL DEFAULT 'OPEN',
    due_date DATE NULL,
    resolution VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    resolved_at DATETIME NULL,
    CONSTRAINT fk_recon_exception_finding FOREIGN KEY (finding_id)
        REFERENCES reconciliation_findings(finding_id) ON DELETE SET NULL,
    INDEX idx_recon_exception_state (state, priority, due_date),
    INDEX idx_recon_exception_owner (owner_email, state)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS recon_exception_note (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    exception_id BIGINT NOT NULL,
    author_email VARCHAR(100) NOT NULL,
    body VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_recon_exception_note FOREIGN KEY (exception_id)
        REFERENCES recon_exception(id) ON DELETE CASCADE,
    INDEX idx_recon_exception_note (exception_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS recon_exception_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    exception_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_recon_exception_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dispute_notification_template (
    template_code VARCHAR(40) PRIMARY KEY,
    purpose VARCHAR(32) NOT NULL,
    channel ENUM('EMAIL','INAPP') NOT NULL DEFAULT 'EMAIL',
    subject VARCHAR(160) NOT NULL,
    body VARCHAR(1000) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_dispute_notification_template (purpose, channel, enabled)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dispute_notification (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NOT NULL,
    recipient VARCHAR(100) NOT NULL,
    purpose VARCHAR(32) NOT NULL,
    template_code VARCHAR(40) NULL,
    channel ENUM('EMAIL','INAPP') NOT NULL DEFAULT 'EMAIL',
    state ENUM('PENDING','SENDING','SENT','FAILED','DEAD') NOT NULL DEFAULT 'PENDING',
    attempts INT NOT NULL DEFAULT 0,
    last_error VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at DATETIME NULL,
    CONSTRAINT fk_dispute_notification_case FOREIGN KEY (case_id)
        REFERENCES dispute_cases(case_id) ON DELETE CASCADE,
    CONSTRAINT fk_dispute_notification_template FOREIGN KEY (template_code)
        REFERENCES dispute_notification_template(template_code) ON DELETE SET NULL,
    INDEX idx_dispute_notification_state (state, created_at),
    INDEX idx_dispute_notification_case (case_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dispute_notification_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    case_id BIGINT NULL,
    notification_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_dispute_notification_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
