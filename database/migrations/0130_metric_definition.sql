CREATE TABLE IF NOT EXISTS metric_definition (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    metric_ref VARCHAR(40) NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    metric_type VARCHAR(20) NOT NULL,
    target_value DECIMAL(18,4) NOT NULL DEFAULT 0,
    actual_value DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','CALCULATED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    calculated_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_metric_definition_ref (metric_ref),
    INDEX idx_metric_definition_status (status, metric_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS metric_definition_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    metric_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_metric_definition_audit_actor (actor_email, created_at),
    INDEX idx_metric_definition_audit_metric (metric_id, created_at)
) ENGINE=InnoDB;
