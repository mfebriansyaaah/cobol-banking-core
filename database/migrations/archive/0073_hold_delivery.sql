-- Phase 1 Sprint 1 slice 18: payment holds and on-call delivery tracking.

CREATE TABLE IF NOT EXISTS payment_hold (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    currency CHAR(3) NOT NULL,
    status ENUM('ACTIVE','CAPTURED','RELEASED','EXPIRED','FAILED') NOT NULL DEFAULT 'ACTIVE',
    expires_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    captured_at DATETIME NULL,
    released_at DATETIME NULL,
    CONSTRAINT fk_payment_hold_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id) ON DELETE CASCADE,
    INDEX idx_payment_hold_status (status, expires_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payment_hold_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    hold_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_payment_hold_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS oncall_delivery (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    page_id BIGINT NOT NULL,
    channel ENUM('EMAIL','PAGE') NOT NULL,
    target_email VARCHAR(100) NOT NULL,
    status ENUM('QUEUED','SENT','DELIVERED','FAILED','CONFIRMED') NOT NULL DEFAULT 'QUEUED',
    retry_count INT NOT NULL DEFAULT 0,
    max_retries INT NOT NULL DEFAULT 3,
    sent_at DATETIME NULL,
    delivered_at DATETIME NULL,
    confirmed_at DATETIME NULL,
    detail VARCHAR(255) NULL,
    CONSTRAINT fk_oncall_delivery_page FOREIGN KEY (page_id)
        REFERENCES oncall_page(id) ON DELETE CASCADE,
    INDEX idx_oncall_delivery_status (status, page_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS oncall_delivery_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    delivery_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_oncall_delivery_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
