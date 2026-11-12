CREATE TABLE IF NOT EXISTS change_approval (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    change_ref VARCHAR(40) NOT NULL,
    title VARCHAR(100) NOT NULL,
    change_type VARCHAR(20) NOT NULL,
    impact_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    approved_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','APPROVED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    approved_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_change_approval_ref (change_ref),
    INDEX idx_change_approval_status (status, change_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS change_approval_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    change_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_change_approval_audit_actor (actor_email, created_at),
    INDEX idx_change_approval_audit_change (change_id, created_at)
) ENGINE=InnoDB;
