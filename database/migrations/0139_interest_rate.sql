CREATE TABLE IF NOT EXISTS interest_rate (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rate_ref VARCHAR(40) NOT NULL,
    rate_name VARCHAR(100) NOT NULL,
    rate_type VARCHAR(20) NOT NULL,
    rate_value DECIMAL(18,4) NOT NULL DEFAULT 0,
    applied_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','RETIRED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_interest_rate_ref (rate_ref),
    INDEX idx_interest_rate_status (status, rate_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS interest_rate_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rate_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_interest_rate_audit_actor (actor_email, created_at),
    INDEX idx_interest_rate_audit_rate (rate_id, created_at)
) ENGINE=InnoDB;
