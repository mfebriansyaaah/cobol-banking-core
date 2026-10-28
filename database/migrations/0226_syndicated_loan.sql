CREATE TABLE IF NOT EXISTS syndicated_loan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    synd_ref VARCHAR(40) NOT NULL,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL,
    budget_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    spent_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    closed_at DATETIME NULL,
    closure_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_syndicated_loan_ref (synd_ref),
    INDEX idx_syndicated_loan_status (status, type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS syndicated_loan_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    syndicated_loan_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_SYL_audit_actor (actor_email, created_at),
    INDEX idx_SYL_audit_syndicated_loan (syndicated_loan_id, created_at)
) ENGINE=InnoDB;
