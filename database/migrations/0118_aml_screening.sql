-- AML screening lifecycle.

CREATE TABLE IF NOT EXISTS aml_screening (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    screen_ref VARCHAR(40) NOT NULL,
    subject_name VARCHAR(100) NOT NULL,
    screen_type VARCHAR(20) NOT NULL,
    hit_count INT NOT NULL DEFAULT 0,
    risk_score INT NOT NULL DEFAULT 0,
    status ENUM('OPEN','SCREENING','CLEARED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    screened_at DATETIME NULL,
    cleared_at DATETIME NULL,
    closed_at DATETIME NULL,
    closure_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_aml_screening_ref (screen_ref),
    INDEX idx_aml_screening_status (status, screen_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS aml_screening_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    screen_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_aml_screening_audit_actor (actor_email, created_at),
    INDEX idx_aml_screening_audit_case (screen_id, created_at)
) ENGINE=InnoDB;
