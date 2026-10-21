-- Phase 1 Sprint 1 slice 4: EOD calendar/run orchestration and fee/limit/velocity.

CREATE TABLE IF NOT EXISTS fee_rule (
    id INT AUTO_INCREMENT PRIMARY KEY,
    rule_code VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    fee_type ENUM('FLAT','PERCENT','TIERED') NOT NULL,
    currency_code CHAR(3) NOT NULL,
    flat_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    percent_rate DECIMAL(9,6) NOT NULL DEFAULT 0,
    min_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    max_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    priority INT NOT NULL DEFAULT 100,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_fee_rule_type (fee_type, currency_code, enabled),
    CHECK (flat_amount >= 0 AND percent_rate >= 0 AND min_amount >= 0 AND max_amount >= 0),
    CHECK (priority BETWEEN 0 AND 9999)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fee_tier (
    id INT AUTO_INCREMENT PRIMARY KEY,
    rule_id INT NOT NULL,
    tier_no INT NOT NULL,
    from_amount DECIMAL(30,10) NOT NULL,
    to_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    fixed_fee DECIMAL(30,10) NOT NULL DEFAULT 0,
    rate DECIMAL(9,6) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_fee_tier_no (rule_id, tier_no),
    CONSTRAINT fk_fee_tier_rule FOREIGN KEY (rule_id)
        REFERENCES fee_rule(id) ON DELETE CASCADE,
    CHECK (tier_no BETWEEN 1 AND 20),
    CHECK (from_amount >= 0 AND to_amount >= 0 AND fixed_fee >= 0 AND rate >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fee_waiver (
    id INT AUTO_INCREMENT PRIMARY KEY,
    rule_id INT NOT NULL,
    account_email VARCHAR(100) NOT NULL,
    reason VARCHAR(100) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_fee_waiver_lookup (rule_id, account_email, enabled),
    CONSTRAINT fk_fee_waiver_rule FOREIGN KEY (rule_id)
        REFERENCES fee_rule(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS velocity_profile (
    id INT AUTO_INCREMENT PRIMARY KEY,
    profile_code VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    window_seconds INT NOT NULL,
    max_count INT NOT NULL,
    max_amount DECIMAL(30,10) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (window_seconds BETWEEN 1 AND 2592000),
    CHECK (max_count BETWEEN 0 AND 1000000),
    CHECK (max_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS velocity_counter (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_email VARCHAR(100) NOT NULL,
    profile_code VARCHAR(40) NOT NULL,
    window_start DATETIME NOT NULL,
    used_count INT NOT NULL DEFAULT 0,
    used_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_velocity_window (account_email, profile_code, window_start),
    CHECK (used_count >= 0 AND used_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fee_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    rule_code VARCHAR(40) NULL,
    account_email VARCHAR(100) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_fee_audit_actor (actor_email, created_at),
    INDEX idx_fee_audit_rule (rule_code, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS eod_calendar (
    business_date DATE PRIMARY KEY,
    status ENUM('OPEN','CLOSED') NOT NULL DEFAULT 'OPEN',
    cutoff_time TIME NOT NULL,
    opened_by VARCHAR(100) NOT NULL,
    opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    closed_by VARCHAR(100) NULL,
    closed_at DATETIME NULL,
    version INT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS eod_run (
    id INT AUTO_INCREMENT PRIMARY KEY,
    business_date DATE NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    phase_count INT NOT NULL DEFAULT 5,
    completed_phases INT NOT NULL DEFAULT 0,
    control_debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    control_credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    version INT NOT NULL DEFAULT 0,
    INDEX idx_eod_run_date (business_date, status),
    CHECK (phase_count >= 0 AND completed_phases >= 0),
    CHECK (control_debit >= 0 AND control_credit >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS eod_phase (
    id INT AUTO_INCREMENT PRIMARY KEY,
    run_id INT NOT NULL,
    phase_no INT NOT NULL,
    phase_code ENUM('FEE','HOLD','DORMANT','STATEMENT','RECON') NOT NULL,
    status ENUM('PENDING','RUNNING','COMPLETED','FAILED','SKIPPED') NOT NULL DEFAULT 'PENDING',
    processed_count BIGINT NOT NULL DEFAULT 0,
    control_debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    control_credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    started_at DATETIME NULL,
    finished_at DATETIME NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_eod_phase_no (run_id, phase_no),
    UNIQUE KEY uq_eod_phase_code (run_id, phase_code),
    CONSTRAINT fk_eod_phase_run FOREIGN KEY (run_id)
        REFERENCES eod_run(id) ON DELETE CASCADE,
    CHECK (phase_no BETWEEN 1 AND 20),
    CHECK (processed_count >= 0),
    CHECK (control_debit >= 0 AND control_credit >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS eod_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    business_date DATE NULL,
    run_id INT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_eod_audit_actor (actor_email, created_at),
    INDEX idx_eod_audit_run (run_id)
) ENGINE=InnoDB;
