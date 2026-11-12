-- Phase 1 Sprint 1 slice 20: settlement reconciliation and statement delivery.

CREATE TABLE IF NOT EXISTS settlement_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    batch_code VARCHAR(40) NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    matched_count BIGINT NOT NULL DEFAULT 0,
    break_count BIGINT NOT NULL DEFAULT 0,
    started_by VARCHAR(100) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS settlement_item (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    run_id BIGINT NOT NULL,
    txn_ref VARCHAR(64) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('MATCHED','BREAK','RESOLVED') NOT NULL DEFAULT 'BREAK',
    detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_settlement_item_run FOREIGN KEY (run_id)
        REFERENCES settlement_run(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS settlement_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_settlement_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_delivery (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    statement_ref VARCHAR(64) NOT NULL,
    recipient VARCHAR(100) NOT NULL,
    channel ENUM('EMAIL','PORTAL') NOT NULL DEFAULT 'EMAIL',
    status ENUM('QUEUED','SENT','DELIVERED','FAILED') NOT NULL DEFAULT 'QUEUED',
    retry_count INT NOT NULL DEFAULT 0,
    max_retries INT NOT NULL DEFAULT 3,
    sent_at DATETIME NULL,
    delivered_at DATETIME NULL,
    detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_delivery_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    delivery_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_statement_delivery_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
