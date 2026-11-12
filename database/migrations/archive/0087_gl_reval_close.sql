-- Phase 1 Sprint 1 slice 32: GL revaluation and period close.

CREATE TABLE IF NOT EXISTS gl_revaluation_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    period VARCHAR(20) NOT NULL,
    currency CHAR(3) NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    matched_count BIGINT NOT NULL DEFAULT 0,
    diff_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS gl_revaluation_line (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    run_id BIGINT NOT NULL,
    account_code VARCHAR(20) NOT NULL,
    original_balance DECIMAL(18,4) NOT NULL DEFAULT 0,
    revalued_balance DECIMAL(18,4) NOT NULL DEFAULT 0,
    diff DECIMAL(18,4) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_gl_reval_line_run FOREIGN KEY (run_id)
        REFERENCES gl_revaluation_run(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS gl_revaluation_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gl_reval_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS gl_period_lock (
    period VARCHAR(20) PRIMARY KEY,
    status ENUM('OPEN','LOCKED','CLOSED') NOT NULL DEFAULT 'OPEN',
    locked_by VARCHAR(100) NULL,
    locked_at DATETIME NULL,
    closed_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS gl_period_lock_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    period VARCHAR(20) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gl_period_lock_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
