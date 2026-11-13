-- Phase 1 Sprint 1 slice 21: audit snapshots and report archives.

CREATE TABLE IF NOT EXISTS audit_snapshot (
    snapshot_code VARCHAR(40) PRIMARY KEY,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    total_events BIGINT NOT NULL DEFAULT 0,
    success_count BIGINT NOT NULL DEFAULT 0,
    failed_count BIGINT NOT NULL DEFAULT 0,
    checksum CHAR(64) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (period_end >= period_start)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_snapshot_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    snapshot_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_snapshot_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_archive (
    archive_code VARCHAR(40) PRIMARY KEY,
    report_type VARCHAR(40) NOT NULL,
    period VARCHAR(40) NOT NULL,
    row_count BIGINT NOT NULL DEFAULT 0,
    checksum CHAR(64) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_archive_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    archive_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_report_archive_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
