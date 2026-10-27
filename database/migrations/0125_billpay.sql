-- Bill pay lifecycle.

CREATE TABLE IF NOT EXISTS billpay (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    bill_ref VARCHAR(40) NOT NULL,
    payee VARCHAR(100) NOT NULL,
    bill_type VARCHAR(20) NOT NULL,
    bill_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    paid_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','PAID','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    paid_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_billpay_ref (bill_ref),
    INDEX idx_billpay_status (status, bill_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS billpay_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    bill_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_billpay_audit_actor (actor_email, created_at),
    INDEX idx_billpay_audit_bill (bill_id, created_at)
) ENGINE=InnoDB;
