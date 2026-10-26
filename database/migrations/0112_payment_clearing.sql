-- D5 payments: clearing/settlement lifecycle.

CREATE TABLE IF NOT EXISTS payment_clearing (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    clearing_ref VARCHAR(40) NOT NULL,
    amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL,
    payment_ref VARCHAR(40) NULL,
    status ENUM('OPEN','POSTED','SETTLED','CANCELLED') NOT NULL DEFAULT 'OPEN',
    posted_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    settled_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    posted_at DATETIME NULL,
    settled_at DATETIME NULL,
    cancelled_at DATETIME NULL,
    cancellation_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_payment_clearing_ref (clearing_ref),
    INDEX idx_payment_clearing_status (status, currency)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payment_clearing_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    clearing_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_payment_clearing_audit_actor (actor_email, created_at),
    INDEX idx_payment_clearing_audit_case (clearing_id, created_at)
) ENGINE=InnoDB;
