CREATE TABLE IF NOT EXISTS standing_order (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_ref VARCHAR(40) NOT NULL,
    payee_name VARCHAR(100) NOT NULL,
    order_type VARCHAR(20) NOT NULL,
    limit_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    used_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CANCELLED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    next_run DATETIME NULL,
    cancelled_at DATETIME NULL,
    cancel_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_standing_order_ref (order_ref),
    INDEX idx_standing_order_status (status, order_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS standing_order_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    standing_order_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_standing_order_audit_actor (actor_email, created_at),
    INDEX idx_standing_order_audit_standing_order (standing_order_id, created_at)
) ENGINE=InnoDB;
