CREATE TABLE IF NOT EXISTS standing_instruction (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    instruction_ref VARCHAR(40) NOT NULL,
    instruction_name VARCHAR(100) NOT NULL,
    instruction_type VARCHAR(20) NOT NULL,
    max_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    executed_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','INACTIVE','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    deactivated_at DATETIME NULL,
    deactivate_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_standing_instruction_ref (instruction_ref),
    INDEX idx_standing_instruction_status (status, instruction_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS standing_instruction_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    standing_instruction_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_standing_instruction_audit_actor (actor_email, created_at),
    INDEX idx_standing_instruction_audit_instruction (standing_instruction_id, created_at)
) ENGINE=InnoDB;
