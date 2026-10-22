-- Phase 1 Sprint 1 slice 16: export download tokens and alert escalation.

CREATE TABLE IF NOT EXISTS export_download_token (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    token VARCHAR(64) NOT NULL UNIQUE,
    archive_id BIGINT NOT NULL,
    expires_at DATETIME NOT NULL,
    download_count BIGINT NOT NULL DEFAULT 0,
    max_downloads BIGINT NOT NULL DEFAULT 5,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_export_download_archive FOREIGN KEY (archive_id)
        REFERENCES export_archive(id) ON DELETE CASCADE,
    INDEX idx_export_download_expiry (expires_at),
    CHECK (max_downloads BETWEEN 1 AND 1000)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS alert_escalation_policy (
    policy_code VARCHAR(40) PRIMARY KEY,
    alert_type VARCHAR(32) NOT NULL,
    severity_min ENUM('INFO','WARNING','CRITICAL') NOT NULL DEFAULT 'WARNING',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS alert_escalation_step (
    id INT AUTO_INCREMENT PRIMARY KEY,
    policy_code VARCHAR(40) NOT NULL,
    step_no INT NOT NULL,
    delay_minutes INT NOT NULL DEFAULT 0,
    target_email VARCHAR(100) NOT NULL,
    channel ENUM('EMAIL','PAGE') NOT NULL DEFAULT 'EMAIL',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_alert_escalation_step_policy FOREIGN KEY (policy_code)
        REFERENCES alert_escalation_policy(policy_code) ON DELETE CASCADE,
    UNIQUE KEY uq_alert_escalation_step (policy_code, step_no),
    CHECK (step_no BETWEEN 1 AND 20),
    CHECK (delay_minutes BETWEEN 0 AND 1440)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS alert_escalation_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alert_id BIGINT NOT NULL,
    policy_code VARCHAR(40) NOT NULL,
    step_no INT NOT NULL,
    target_email VARCHAR(100) NOT NULL,
    status ENUM('PENDING','PAGED','ACKED','RESOLVED','FAILED') NOT NULL DEFAULT 'PENDING',
    detail VARCHAR(255) NULL,
    paged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acked_at DATETIME NULL,
    resolved_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    INDEX idx_alert_escalation_status (status, paged_at),
    INDEX idx_alert_escalation_alert (alert_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS alert_escalation_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_alert_escalation_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
