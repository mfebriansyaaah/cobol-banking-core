-- PR-801: Loyalty — member/ledger/redemption/campaign/audit.

CREATE TABLE IF NOT EXISTS loyalty_member (
    member_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    program_id BIGINT NOT NULL,
    customer_ref VARCHAR(40) NOT NULL,
    tier VARCHAR(20) NOT NULL DEFAULT 'STANDARD',
    points_balance DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('ACTIVE','SUSPENDED','CLOSED') NOT NULL DEFAULT 'ACTIVE',
    joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INT NOT NULL DEFAULT 1,
    CONSTRAINT fk_loyalty_member_program FOREIGN KEY (program_id)
        REFERENCES loyalty_program (id) ON DELETE CASCADE,
    UNIQUE KEY uq_loyalty_member (program_id, customer_ref),
    INDEX idx_loyalty_member_program (program_id, status),
    CHECK (points_balance >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loyalty_points_ledger (
    entry_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    member_id BIGINT NOT NULL,
    source_type ENUM('CARD_TXN','PAYMENT','CAMPAIGN','ADJUSTMENT','REDEMPTION','EXPIRY') NOT NULL,
    source_ref VARCHAR(50) NOT NULL,
    points_delta DECIMAL(18,4) NOT NULL,
    balance_after DECIMAL(18,4) NOT NULL,
    expires_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reversed_at DATETIME NULL,
    CONSTRAINT fk_loyalty_ledger_member FOREIGN KEY (member_id)
        REFERENCES loyalty_member (member_id) ON DELETE CASCADE,
    UNIQUE KEY uq_loyalty_ledger_source (member_id, source_type, source_ref),
    INDEX idx_loyalty_ledger_member (member_id, created_at),
    CHECK (balance_after >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loyalty_redemption (
    redemption_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    member_id BIGINT NOT NULL,
    points DECIMAL(18,4) NOT NULL,
    reward_code VARCHAR(40) NOT NULL,
    status ENUM('REQUESTED','APPROVED','FULFILLED','CANCELLED') NOT NULL DEFAULT 'REQUESTED',
    gl_journal_id BIGINT NULL,
    requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fulfilled_at DATETIME NULL,
    CONSTRAINT fk_loyalty_redemption_member FOREIGN KEY (member_id)
        REFERENCES loyalty_member (member_id) ON DELETE CASCADE,
    INDEX idx_loyalty_redemption_member (member_id, status),
    CHECK (points > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loyalty_campaign (
    campaign_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    program_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    bonus_points DECIMAL(18,4) NOT NULL DEFAULT 0,
    start_date DATE NULL,
    end_date DATE NULL,
    status ENUM('DRAFT','ACTIVE','ENDED') NOT NULL DEFAULT 'DRAFT',
    CONSTRAINT fk_loyalty_campaign_program FOREIGN KEY (program_id)
        REFERENCES loyalty_program (id) ON DELETE CASCADE,
    INDEX idx_loyalty_campaign_program (program_id, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loyalty_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    member_id BIGINT NULL,
    program_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_loyalty_audit_actor (actor_email, created_at),
    INDEX idx_loyalty_audit_member (member_id, created_at)
) ENGINE=InnoDB;
