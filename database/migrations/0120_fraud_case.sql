-- Fraud case lifecycle.

CREATE TABLE IF NOT EXISTS fraud_case (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_ref VARCHAR(40) NOT NULL,
    account_ref VARCHAR(100) NOT NULL,
    fraud_type VARCHAR(20) NOT NULL,
    alert_count INT NOT NULL DEFAULT 0,
    risk_level INT NOT NULL DEFAULT 0,
    status ENUM('OPEN','INVESTIGATING','CONFIRMED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    screened_at DATETIME NULL,
    resolved_at DATETIME NULL,
    closed_at DATETIME NULL,
    closure_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_fraud_case_ref (case_ref),
    INDEX idx_fraud_case_status (status, fraud_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fraud_case_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_fraud_case_audit_actor (actor_email, created_at),
    INDEX idx_fraud_case_audit_case (case_id, created_at)
) ENGINE=InnoDB;
