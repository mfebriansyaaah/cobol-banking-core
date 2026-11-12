-- Phase 2 slice: observability (SLO reports and pipeline alerts).

CREATE TABLE IF NOT EXISTS slo_definition (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    slo_name VARCHAR(64) NOT NULL,
    target_pct DECIMAL(5,2) NOT NULL,
    window_days INT NOT NULL DEFAULT 30,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_slo_name (slo_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS slo_measurement (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    slo_name VARCHAR(64) NOT NULL,
    window_start DATETIME NULL,
    window_end DATETIME NULL,
    good_events BIGINT NOT NULL DEFAULT 0,
    total_events BIGINT NOT NULL DEFAULT 0,
    burn_rate DECIMAL(8,4) NOT NULL DEFAULT 0,
    status ENUM('OK','BREACHED') NOT NULL DEFAULT 'OK',
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    recorded_by VARCHAR(100) NOT NULL,
    INDEX idx_slo_measurement_name (slo_name, recorded_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS slo_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    slo_name VARCHAR(64) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_slo_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pipeline_alert (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pipeline_name VARCHAR(100) NOT NULL,
    severity ENUM('INFO','WARNING','CRITICAL') NOT NULL DEFAULT 'INFO',
    status ENUM('OPEN','ACKNOWLEDGED','RESOLVED') NOT NULL DEFAULT 'OPEN',
    message VARCHAR(255) NOT NULL,
    source_key VARCHAR(100) NOT NULL,
    occurrence_count BIGINT NOT NULL DEFAULT 1,
    first_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acknowledged_by VARCHAR(100) NULL,
    resolved_by VARCHAR(100) NULL,
    resolved_at DATETIME NULL,
    detail VARCHAR(255) NULL,
    UNIQUE KEY uq_pipeline_alert_source (source_key, status),
    INDEX idx_pipeline_alert_status (status, severity)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pipeline_alert_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    alert_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_pipeline_alert_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
