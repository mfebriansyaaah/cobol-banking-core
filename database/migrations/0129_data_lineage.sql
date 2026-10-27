CREATE TABLE IF NOT EXISTS data_lineage (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    lineage_ref VARCHAR(40) NOT NULL,
    source_name VARCHAR(100) NOT NULL,
    lineage_type VARCHAR(20) NOT NULL,
    record_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    tracked_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','TRACKED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    tracked_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_data_lineage_ref (lineage_ref),
    INDEX idx_data_lineage_status (status, lineage_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS data_lineage_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    lineage_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_data_lineage_audit_actor (actor_email, created_at),
    INDEX idx_data_lineage_audit_lineage (lineage_id, created_at)
) ENGINE=InnoDB;
