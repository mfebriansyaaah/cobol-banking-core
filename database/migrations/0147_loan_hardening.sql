CREATE TABLE IF NOT EXISTS loan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    loan_ref VARCHAR(40) NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    loan_type VARCHAR(20) NOT NULL,
    loan_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    disbursed_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    disbursed_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_loan_ref (loan_ref),
    INDEX idx_loan_status (status, loan_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loan_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    loan_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_loan_audit_actor (actor_email, created_at),
    INDEX idx_loan_audit_loan (loan_id, created_at)
) ENGINE=InnoDB;
