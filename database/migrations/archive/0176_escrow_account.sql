CREATE TABLE IF NOT EXISTS escrow_account (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    escrow_ref VARCHAR(40) NOT NULL,
    escrow_name VARCHAR(100) NOT NULL,
    escrow_type VARCHAR(20) NOT NULL,
    deposit_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    released_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','RELEASED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deposited_at DATETIME NULL,
    released_at DATETIME NULL,
    release_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_escrow_account_ref (escrow_ref),
    INDEX idx_escrow_account_status (status, escrow_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS escrow_account_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    escrow_account_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ESC_audit_actor (actor_email, created_at),
    INDEX idx_ESC_audit_escrow_account (escrow_account_id, created_at)
) ENGINE=InnoDB;
