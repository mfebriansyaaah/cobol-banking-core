-- PR-301: Merchant Acquiring — merchant registry + fee profile + transaction.
-- Extends merchant with owner/account/risk and onboarding lifecycle.
-- Legacy generic modules are untouched here (deprecation in PR-304).

ALTER TABLE merchant
    ADD COLUMN IF NOT EXISTS customer_ref VARCHAR(40) NULL AFTER merchant_ref,
    ADD COLUMN IF NOT EXISTS settlement_account_id INT NULL AFTER merchant_type,
    ADD COLUMN IF NOT EXISTS fee_profile_id BIGINT NULL AFTER settlement_account_id,
    ADD COLUMN IF NOT EXISTS risk_level ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM' AFTER fee_profile_id,
    ADD COLUMN IF NOT EXISTS onboarded_at DATETIME NULL AFTER created_at;

-- Broaden status to the onboarding lifecycle while keeping legacy values.
ALTER TABLE merchant
    MODIFY COLUMN status ENUM('OPEN','ACTIVE','CLOSED','DELETED','PROSPECT','PENDING_KYC','SUSPENDED')
    NOT NULL DEFAULT 'PROSPECT';

CREATE INDEX IF NOT EXISTS idx_merchant_customer ON merchant (customer_ref, status);

CREATE TABLE IF NOT EXISTS merchant_fee_profile (
    fee_profile_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    merchant_id BIGINT NOT NULL,
    mdr_pct DECIMAL(5,2) NOT NULL DEFAULT 0,
    fixed_fee DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'IDR',
    effective_from DATE NOT NULL DEFAULT (CURRENT_DATE),
    effective_to DATE NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_fee_profile_merchant FOREIGN KEY (merchant_id)
        REFERENCES merchant (id) ON DELETE CASCADE,
    INDEX idx_fee_profile_merchant (merchant_id, effective_from),
    CHECK (mdr_pct BETWEEN 0 AND 100),
    CHECK (fixed_fee >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS merchant_transaction (
    merchant_txn_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    merchant_id BIGINT NOT NULL,
    payment_clearing_ref VARCHAR(40) NULL,
    card_txn_ref VARCHAR(64) NULL,
    txn_ref VARCHAR(50) NOT NULL,
    amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'IDR',
    fee_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    net_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('CAPTURED','SETTLED','REFUNDED','CHARGEBACK') NOT NULL DEFAULT 'CAPTURED',
    captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    settlement_id BIGINT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_merchant_txn_merchant FOREIGN KEY (merchant_id)
        REFERENCES merchant (id) ON DELETE CASCADE,
    UNIQUE KEY uq_merchant_txn_ref (txn_ref),
    INDEX idx_merchant_txn_merchant (merchant_id, status),
    INDEX idx_merchant_txn_settlement (settlement_id),
    CHECK (amount > 0),
    CHECK (fee_amount >= 0)
) ENGINE=InnoDB;
