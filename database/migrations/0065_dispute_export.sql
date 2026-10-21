-- Phase 1 Sprint 1 slice 9: dispute operations and retained exports.

ALTER TABLE dispute_cases
    ADD COLUMN IF NOT EXISTS priority ENUM('LOW','NORMAL','HIGH','URGENT')
        NOT NULL DEFAULT 'NORMAL' AFTER state,
    ADD INDEX IF NOT EXISTS idx_dispute_priority (priority, state, due_date);

CREATE TABLE IF NOT EXISTS dispute_sla_policy (
    priority ENUM('LOW','NORMAL','HIGH','URGENT') PRIMARY KEY,
    response_hours INT NOT NULL DEFAULT 24,
    resolution_hours INT NOT NULL DEFAULT 72,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (response_hours BETWEEN 1 AND 8760),
    CHECK (resolution_hours BETWEEN 1 AND 8760),
    CHECK (response_hours <= resolution_hours)
) ENGINE=InnoDB;

INSERT IGNORE INTO dispute_sla_policy
    (priority, response_hours, resolution_hours, enabled, updated_by)
VALUES
    ('LOW', 72, 168, TRUE, 'SYSTEM'),
    ('NORMAL', 24, 72, TRUE, 'SYSTEM'),
    ('HIGH', 8, 24, TRUE, 'SYSTEM'),
    ('URGENT', 2, 8, TRUE, 'SYSTEM');

CREATE TABLE IF NOT EXISTS dispute_assignment (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NOT NULL,
    from_user_id INT NULL,
    to_user_id INT NULL,
    assigned_by VARCHAR(100) NOT NULL,
    note VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_dispute_assignment_case FOREIGN KEY (case_id)
        REFERENCES dispute_cases(case_id) ON DELETE CASCADE,
    CONSTRAINT fk_dispute_assignment_from FOREIGN KEY (from_user_id)
        REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_dispute_assignment_to FOREIGN KEY (to_user_id)
        REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_dispute_assignment_case (case_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dispute_ops_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    case_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_dispute_ops_actor (actor_email, created_at),
    INDEX idx_dispute_ops_case (case_id, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS export_archive (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    export_type ENUM('REPORT','IMPORT') NOT NULL,
    source_code VARCHAR(64) NOT NULL,
    format ENUM('CSV','JSON','FIXED') NOT NULL DEFAULT 'CSV',
    content LONGTEXT NOT NULL,
    checksum CHAR(64) NOT NULL,
    row_count BIGINT NOT NULL DEFAULT 0,
    byte_count BIGINT NOT NULL DEFAULT 0,
    retention_days INT NOT NULL DEFAULT 365,
    expires_at DATE NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_export_archive_source (export_type, source_code, format),
    INDEX idx_export_archive_source (export_type, source_code),
    INDEX idx_export_archive_expiry (expires_at),
    CHECK (retention_days BETWEEN 1 AND 3650),
    CHECK (row_count >= 0 AND byte_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS export_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    archive_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_export_audit_actor (actor_email, created_at),
    INDEX idx_export_audit_archive (archive_id)
) ENGINE=InnoDB;
