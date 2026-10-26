-- Deposit & interest lifecycle (D2).
-- Extends the term-deposit ledger with accrual, posting and settlement.

ALTER TABLE deposit_account
    ADD COLUMN IF NOT EXISTS accrued_interest DECIMAL(18,4) NOT NULL DEFAULT 0;
ALTER TABLE deposit_account
    ADD COLUMN IF NOT EXISTS posted_interest DECIMAL(18,4) NOT NULL DEFAULT 0;
ALTER TABLE deposit_account
    ADD COLUMN IF NOT EXISTS last_accrual_date DATE NULL;

CREATE TABLE IF NOT EXISTS deposit_accrual (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    deposit_id BIGINT NOT NULL,
    accrual_date DATE NOT NULL,
    days INT NOT NULL,
    principal DECIMAL(18,4) NOT NULL,
    rate DECIMAL(9,4) NOT NULL,
    interest DECIMAL(18,4) NOT NULL,
    status ENUM('ACCRUED','POSTED') NOT NULL DEFAULT 'ACCRUED',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_deposit_accrual (deposit_id, accrual_date),
    INDEX idx_deposit_accrual_status (deposit_id, status),
    CONSTRAINT fk_deposit_accrual FOREIGN KEY (deposit_id)
        REFERENCES deposit_account (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS deposit_transaction (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    deposit_id BIGINT NOT NULL,
    txn_type ENUM('INTEREST_POSTED','PRINCIPAL_PAYOUT','SETTLE') NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    currency CHAR(3) NOT NULL,
    reference VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_deposit_txn (deposit_id, created_at),
    CONSTRAINT fk_deposit_txn FOREIGN KEY (deposit_id)
        REFERENCES deposit_account (id) ON DELETE CASCADE
) ENGINE=InnoDB;
