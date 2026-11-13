CREATE TABLE IF NOT EXISTS user_activity (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    activity_ref VARCHAR(40) NOT NULL,
    user_name VARCHAR(100) NOT NULL,
    activity_type VARCHAR(20) NOT NULL,
    session_limit DECIMAL(18,4) NOT NULL DEFAULT 0,
    session_count DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','ENDED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    started_at DATETIME NULL,
    ended_at DATETIME NULL,
    end_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_user_activity_ref (activity_ref),
    INDEX idx_user_activity_status (status, activity_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS user_activity_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_activity_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_UAC_audit_actor (actor_email, created_at),
    INDEX idx_UAC_audit_user_activity (user_activity_id, created_at)
) ENGINE=InnoDB;
