-- Sanctions list lifecycle.

CREATE TABLE IF NOT EXISTS sanctions_list (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    list_ref VARCHAR(40) NOT NULL,
    entity_name VARCHAR(100) NOT NULL,
    list_type VARCHAR(20) NOT NULL,
    match_count INT NOT NULL DEFAULT 0,
    priority_score INT NOT NULL DEFAULT 0,
    status ENUM('OPEN','CHECKING','RESOLVED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    checked_at DATETIME NULL,
    resolved_at DATETIME NULL,
    closed_at DATETIME NULL,
    closure_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_sanctions_list_ref (list_ref),
    INDEX idx_sanctions_list_status (status, list_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sanctions_list_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    list_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_sanctions_list_audit_actor (actor_email, created_at),
    INDEX idx_sanctions_list_audit_case (list_id, created_at)
) ENGINE=InnoDB;
