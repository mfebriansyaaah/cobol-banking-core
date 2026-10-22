-- Phase 1 Sprint 1 slice 13: standing payment instructions and on-call routing.

CREATE TABLE IF NOT EXISTS payment_instruction (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    instruction_code VARCHAR(40) NOT NULL UNIQUE,
    from_email VARCHAR(100) NOT NULL,
    to_email VARCHAR(100) NOT NULL,
    amount DECIMAL(30,10) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    frequency ENUM('ONCE','DAILY','WEEKLY','MONTHLY') NOT NULL DEFAULT 'ONCE',
    next_run_date DATE NOT NULL DEFAULT '1970-01-01',
    end_date DATE NULL,
    status ENUM('ACTIVE','PAUSED','CANCELLED','COMPLETED') NOT NULL DEFAULT 'ACTIVE',
    last_run_at DATETIME NULL,
    last_txn_ref VARCHAR(50) NULL,
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_payment_instruction_due (status, next_run_date),
    INDEX idx_payment_instruction_from (from_email, status),
    CHECK (amount > 0),
    CHECK (end_date IS NULL OR end_date >= next_run_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payment_instruction_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    instruction_id BIGINT NOT NULL,
    status ENUM('COMPLETED','FAILED') NOT NULL,
    txn_ref VARCHAR(50) NULL,
    error_detail VARCHAR(255) NULL,
    run_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100) NOT NULL,
    CONSTRAINT fk_payment_instruction_run FOREIGN KEY (instruction_id)
        REFERENCES payment_instruction(id) ON DELETE CASCADE,
    INDEX idx_payment_instruction_run (instruction_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS oncall_rotation (
    id INT AUTO_INCREMENT PRIMARY KEY,
    rotation_code VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS oncall_shift (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rotation_id INT NOT NULL,
    user_email VARCHAR(100) NOT NULL,
    starts_at DATETIME NOT NULL,
    ends_at DATETIME NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_oncall_shift_rotation FOREIGN KEY (rotation_id)
        REFERENCES oncall_rotation(id) ON DELETE CASCADE,
    INDEX idx_oncall_shift_window (rotation_id, starts_at, ends_at),
    CHECK (ends_at > starts_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS escalation_policy (
    id INT AUTO_INCREMENT PRIMARY KEY,
    policy_code VARCHAR(40) NOT NULL UNIQUE,
    alert_type VARCHAR(32) NOT NULL,
    severity_min ENUM('INFO','WARNING','CRITICAL') NOT NULL DEFAULT 'WARNING',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS escalation_step (
    id INT AUTO_INCREMENT PRIMARY KEY,
    policy_id INT NOT NULL,
    step_no INT NOT NULL,
    delay_minutes INT NOT NULL DEFAULT 0,
    target_email VARCHAR(100) NOT NULL,
    channel ENUM('EMAIL','PAGE') NOT NULL DEFAULT 'EMAIL',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_escalation_step_policy FOREIGN KEY (policy_id)
        REFERENCES escalation_policy(id) ON DELETE CASCADE,
    UNIQUE KEY uq_escalation_step (policy_id, step_no),
    CHECK (step_no BETWEEN 1 AND 20),
    CHECK (delay_minutes BETWEEN 0 AND 1440)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS oncall_page (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alert_id BIGINT NOT NULL,
    policy_id INT NULL,
    step_no INT NOT NULL DEFAULT 1,
    target_email VARCHAR(100) NOT NULL,
    status ENUM('PAGED','ACKED','RESOLVED','FAILED') NOT NULL DEFAULT 'PAGED',
    detail VARCHAR(255) NULL,
    paged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acked_at DATETIME NULL,
    resolved_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    CONSTRAINT fk_oncall_page_policy FOREIGN KEY (policy_id)
        REFERENCES escalation_policy(id) ON DELETE SET NULL,
    INDEX idx_oncall_page_status (status, paged_at),
    INDEX idx_oncall_page_alert (alert_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS oncall_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    page_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_oncall_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
