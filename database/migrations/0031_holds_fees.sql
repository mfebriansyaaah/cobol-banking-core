-- Migration 0031: holds and scheduled fees.
-- 1) account_holds: locks part of an account's balance. PLACED holds reduce
--    the spendable (available) balance; RELEASED/EXPIRED rows are history.
--    Expiry is lazy (transfers expire what they meet) plus explicit release.
-- 2) fee_schedule: bank-owned per-currency flat fee in major units. No row
--    means no fee. Amounts live in data, never in code, so pricing stays an
--    owner decision (Gate 0); the core only applies what is configured.
-- 3) Fee income accounts use account_type FEE_INCOME (one active per
--    currency); fee postings get their own FEE journal.
CREATE TABLE IF NOT EXISTS account_holds (
    hold_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    amount DECIMAL(18, 4) NOT NULL,
    state ENUM('PLACED','RELEASED','EXPIRED') NOT NULL DEFAULT 'PLACED',
    reason VARCHAR(100) NULL,
    actor_email VARCHAR(100) NOT NULL,
    expires_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_hold_amount CHECK (amount > 0),
    KEY idx_hold_account (account_id, state),
    CONSTRAINT fk_hold_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fee_schedule (
    currency_id INT PRIMARY KEY,
    fee_amount DECIMAL(18, 4) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_fee_amount CHECK (fee_amount >= 0),
    CONSTRAINT fk_fee_currency FOREIGN KEY (currency_id)
        REFERENCES currencies(currency_id)
) ENGINE=InnoDB;

ALTER TABLE accounts MODIFY COLUMN account_type
    ENUM('SAVINGS','CHECKING','INVESTMENT','FEE_INCOME') DEFAULT 'SAVINGS';
ALTER TABLE journal_entries MODIFY COLUMN source
    ENUM('TRANSFER','REVERSAL','FEE') NOT NULL;
