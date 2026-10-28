CREATE TABLE IF NOT EXISTS payroll_processing (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    payroll_ref VARCHAR(40) NOT NULL,
    batch_name VARCHAR(100) NOT NULL,
    payroll_type VARCHAR(20) NOT NULL,
    total_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    processed_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','COMPLETED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    processed_at DATETIME NULL,
    completed_at DATETIME NULL,
    complete_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_payroll_processing_ref (payroll_ref),
    INDEX idx_payroll_processing_status (status, payroll_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS payroll_processing_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    payroll_processing_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_PRL_audit_actor (actor_email, created_at),
    INDEX idx_PRL_audit_payroll_processing (payroll_processing_id, created_at)
) ENGINE=InnoDB;
