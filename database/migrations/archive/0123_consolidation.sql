-- Consolidation lifecycle.

CREATE TABLE IF NOT EXISTS consolidation (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cons_ref VARCHAR(40) NOT NULL,
    entity_name VARCHAR(100) NOT NULL,
    cons_type VARCHAR(20) NOT NULL,
    amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    posted_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','POSTED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    posted_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_consolidation_ref (cons_ref),
    INDEX idx_consolidation_status (status, cons_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS consolidation_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cons_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_consolidation_audit_actor (actor_email, created_at),
    INDEX idx_consolidation_audit_cons (cons_id, created_at)
) ENGINE=InnoDB;
