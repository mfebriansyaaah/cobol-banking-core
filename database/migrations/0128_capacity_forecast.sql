CREATE TABLE IF NOT EXISTS capacity_forecast (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    forecast_ref VARCHAR(40) NOT NULL,
    resource_name VARCHAR(100) NOT NULL,
    forecast_type VARCHAR(20) NOT NULL,
    capacity_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    projected_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','PROJECTED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    projected_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_capacity_forecast_ref (forecast_ref),
    INDEX idx_capacity_forecast_status (status, forecast_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS capacity_forecast_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    forecast_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_capacity_forecast_audit_actor (actor_email, created_at),
    INDEX idx_capacity_forecast_audit_forecast (forecast_id, created_at)
) ENGINE=InnoDB;
