-- Cost center lifecycle.

CREATE TABLE IF NOT EXISTS cost_center (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cc_ref VARCHAR(40) NOT NULL,
    dept_name VARCHAR(100) NOT NULL,
    cc_type VARCHAR(20) NOT NULL,
    budget_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    spent_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','FROZEN','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    allocated_at DATETIME NULL,
    closed_at DATETIME NULL,
    closure_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_cost_center_ref (cc_ref),
    INDEX idx_cost_center_status (status, cc_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cost_center_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cc_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_cost_center_audit_actor (actor_email, created_at),
    INDEX idx_cost_center_audit_case (cc_id, created_at)
) ENGINE=InnoDB;
