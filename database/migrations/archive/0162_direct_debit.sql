CREATE TABLE IF NOT EXISTS direct_debit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    dd_ref VARCHAR(40) NOT NULL,
    mandate_name VARCHAR(100) NOT NULL,
    dd_type VARCHAR(20) NOT NULL,
    max_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    collected_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CANCELLED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    cancelled_at DATETIME NULL,
    cancel_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_direct_debit_ref (dd_ref),
    INDEX idx_direct_debit_status (status, dd_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS direct_debit_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    direct_debit_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_direct_debit_audit_actor (actor_email, created_at),
    INDEX idx_direct_debit_audit_direct (direct_debit_id, created_at)
) ENGINE=InnoDB;
