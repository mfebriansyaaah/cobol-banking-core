CREATE TABLE IF NOT EXISTS customer (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_ref VARCHAR(40) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    customer_type VARCHAR(20) NOT NULL,
    credit_limit DECIMAL(18,4) NOT NULL DEFAULT 0,
    used_credit DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ONBOARDED','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    kyc_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    onboarded_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_customer_ref (customer_ref),
    INDEX idx_customer_status (status, customer_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS customer_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_customer_audit_actor (actor_email, created_at),
    INDEX idx_customer_audit_customer (customer_id, created_at)
) ENGINE=InnoDB;
