CREATE TABLE IF NOT EXISTS analytics_snapshot (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    snapshot_ref VARCHAR(40) NOT NULL,
    report_name VARCHAR(100) NOT NULL,
    snapshot_type VARCHAR(20) NOT NULL,
    row_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    refreshed_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','REFRESHED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    refreshed_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_analytics_snapshot_ref (snapshot_ref),
    INDEX idx_analytics_snapshot_status (status, snapshot_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS analytics_snapshot_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    snapshot_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_analytics_snapshot_audit_actor (actor_email, created_at),
    INDEX idx_analytics_snapshot_audit_snapshot (snapshot_id, created_at)
) ENGINE=InnoDB;
