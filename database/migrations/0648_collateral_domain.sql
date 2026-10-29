-- PR-101: Collateral Management domain tables.
-- Extends `collateral` with owner/currency/description and broadens status
-- to the real lifecycle. Adds valuation / pledge / allocation children.
-- Existing generic modules (collateral_mgmt, collateral_repossession,
-- collateralized) are left untouched for deprecation in PR-104.

-- Extend collateral with domain columns (idempotent guards via ADD COLUMN;
-- MySQL <8 does not support IF NOT EXISTS for ADD COLUMN, so this file must
-- run once via migrate.sh which records versions).
ALTER TABLE collateral
    ADD COLUMN IF NOT EXISTS customer_ref VARCHAR(40) NULL AFTER collateral_ref,
    ADD COLUMN IF NOT EXISTS currency CHAR(3) NOT NULL DEFAULT 'IDR' AFTER asset_type,
    ADD COLUMN IF NOT EXISTS description VARCHAR(255) NULL AFTER asset_name,
    ADD COLUMN IF NOT EXISTS latest_valuation_id BIGINT NULL AFTER appraised_value;

-- Broaden status to the real lifecycle while keeping legacy values
-- (OPEN/ACTIVE) so existing rows keep working.
ALTER TABLE collateral
    MODIFY COLUMN status ENUM('OPEN','ACTIVE','REGISTERED','APPRAISED','PLEDGED','RELEASED','REPOSSESSED','DISPOSED','DELETED')
    NOT NULL DEFAULT 'OPEN';

CREATE INDEX IF NOT EXISTS idx_collateral_customer ON collateral (customer_ref, status);

CREATE TABLE IF NOT EXISTS collateral_valuation (
    valuation_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    collateral_id BIGINT NOT NULL,
    valuation_type ENUM('APPRAISAL','REVALUATION','HAIRCUT') NOT NULL DEFAULT 'APPRAISAL',
    value_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'IDR',
    method VARCHAR(40) NULL,
    valuer VARCHAR(100) NULL,
    valid_until DATE NULL,
    note VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_valuation_collateral FOREIGN KEY (collateral_id)
        REFERENCES collateral (id) ON DELETE CASCADE,
    INDEX idx_valuation_collateral (collateral_id, created_at),
    CHECK (value_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS collateral_pledge (
    pledge_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    collateral_id BIGINT NOT NULL,
    loan_id BIGINT NOT NULL,
    pledge_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    haircut_pct DECIMAL(5,2) NOT NULL DEFAULT 0,
    ltv_pct DECIMAL(5,2) NOT NULL DEFAULT 0,
    status ENUM('PLEDGED','RELEASED') NOT NULL DEFAULT 'PLEDGED',
    pledged_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    released_at DATETIME NULL,
    release_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pledge_collateral FOREIGN KEY (collateral_id)
        REFERENCES collateral (id) ON DELETE CASCADE,
    CONSTRAINT fk_pledge_loan FOREIGN KEY (loan_id)
        REFERENCES loan_application (id) ON DELETE CASCADE,
    UNIQUE KEY uq_pledge_collateral_loan (collateral_id, loan_id, status),
    INDEX idx_pledge_loan (loan_id, status),
    INDEX idx_pledge_collateral (collateral_id, status),
    CHECK (pledge_amount >= 0),
    CHECK (haircut_pct BETWEEN 0 AND 100),
    CHECK (ltv_pct BETWEEN 0 AND 100)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS collateral_allocation (
    allocation_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pledge_id BIGINT NOT NULL,
    loan_id BIGINT NOT NULL,
    allocated_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_allocation_pledge FOREIGN KEY (pledge_id)
        REFERENCES collateral_pledge (pledge_id) ON DELETE CASCADE,
    CONSTRAINT fk_allocation_loan FOREIGN KEY (loan_id)
        REFERENCES loan_application (id) ON DELETE CASCADE,
    INDEX idx_allocation_pledge (pledge_id),
    INDEX idx_allocation_loan (loan_id),
    CHECK (allocated_amount >= 0)
) ENGINE=InnoDB;
