CREATE TABLE IF NOT EXISTS risk_score (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    score_ref VARCHAR(40) NOT NULL,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL,
    budget_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    spent_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    closed_at DATETIME NULL,
    closure_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_risk_score_ref (score_ref),
    INDEX idx_risk_score_status (status, type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS risk_score_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    risk_score_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_RKS_audit_actor (actor_email, created_at),
    INDEX idx_RKS_audit_risk_score (risk_score_id, created_at)
) ENGINE=InnoDB;
