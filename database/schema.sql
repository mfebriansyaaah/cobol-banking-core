-- E-Wallet Enterprise Secure Database Schema
-- Target: MySQL 8.0 (InnoDB, utf8mb4)
-- Purpose: Ensuring Financial Integrity and Strict Identity
-- Version: 1.2.0
-- Changelog:
--   v1.2.0 - Integrated Multi-Currency Accounts and Atomic Ledger
--   v1.1.0 - Fixed index typo, added performance indexes on verification_logs
--   v1.0.0 - Initial schema: users, ledger, verification_logs tables

-- 1. Tabel Users (Identity & Profile)
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    dob DATE NOT NULL,
    status ENUM('UNVERIFIED', 'VERIFIED') DEFAULT 'UNVERIFIED',
    verification_code VARCHAR(6),
    role ENUM('USER', 'MANAGER', 'SUPER_ADMIN') DEFAULT 'USER',
    balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Tabel Currencies (Multi-currency Support)
-- Standard: ISO 4217 (e.g., USD, IDR, EUR)
CREATE TABLE IF NOT EXISTS currencies (
    currency_id INT AUTO_INCREMENT PRIMARY KEY,
    iso_code CHAR(3) NOT NULL UNIQUE, -- 3-letter ISO 4217 Currency Code
    symbol VARCHAR(5) NOT NULL,        -- Currency symbol (e.g., $, Rp)
    prec_val INT DEFAULT 2,           -- Decimal precision for the currency
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO currencies (iso_code, symbol, prec_val) VALUES 
('USD', '$', 2),
('EUR', '€', 2),
('IDR', 'Rp', 0),
('GBP', '£', 2);

-- 3. Tabel Exchange Rates (Currency Conversion)
CREATE TABLE IF NOT EXISTS exchange_rates (
    rate_id INT AUTO_INCREMENT PRIMARY KEY,
    base_currency_id INT NOT NULL,
    target_currency_id INT NOT NULL,
    exchange_rate DECIMAL(18, 6) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_base_curr FOREIGN KEY (base_currency_id) REFERENCES currencies(currency_id),
    CONSTRAINT fk_target_curr FOREIGN KEY (target_currency_id) REFERENCES currencies(currency_id),
    UNIQUE KEY unique_pair (base_currency_id, target_currency_id)
) ENGINE=InnoDB;

INSERT IGNORE INTO exchange_rates (base_currency_id, target_currency_id, exchange_rate) VALUES 
(1, 2, 0.92), -- USD to EUR
(1, 3, 15700.00), -- USD to IDR
(1, 4, 0.79); -- USD to GBP

-- 4. Tabel Accounts (User Financial Accounts)
CREATE TABLE IF NOT EXISTS accounts (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    currency_id INT NOT NULL,
    account_type ENUM('SAVINGS', 'CHECKING', 'INVESTMENT') DEFAULT 'SAVINGS',
    balance DECIMAL(18, 4) NOT NULL DEFAULT 0.0000 CHECK (balance >= 0),
    status ENUM('ACTIVE', 'FROZEN', 'CLOSED') DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_acc_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_acc_curr FOREIGN KEY (currency_id) REFERENCES currencies(currency_id),
    UNIQUE KEY unique_user_currency (user_id, currency_id)
) ENGINE=InnoDB;

-- 5. Tabel Ledger (Refactored for Multi-Currency & Atomic Txns)
DROP TABLE IF EXISTS ledger;
CREATE TABLE IF NOT EXISTS ledger (
    ledger_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    txn_ref VARCHAR(50) NOT NULL,
    account_id INT NOT NULL,
    amount DECIMAL(18, 4) NOT NULL,
    type ENUM('CREDIT', 'DEBIT') NOT NULL,
    currency_id INT NOT NULL,
    description VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ledger_acc FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE CASCADE,
    CONSTRAINT fk_ledger_curr FOREIGN KEY (currency_id) REFERENCES currencies(currency_id)
) ENGINE=InnoDB;

-- 6. Tabel Verification Logs (Anti-Spam & Tracking)
CREATE TABLE IF NOT EXISTS verification_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(100) NOT NULL,
    code VARCHAR(6) NOT NULL,
    purpose ENUM('SIGNUP', 'EMAIL_CHANGE') NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 7. Tabel Audit Trail (Financial Compliance & Security)
CREATE TABLE IF NOT EXISTS audit_trail (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50), -- Contoh: 'ACCOUNT', 'LEDGER', 'USER'
    entity_id VARCHAR(50),   -- ID dari entity yang diubah
    old_value TEXT,
    new_value TEXT,
    ip_address VARCHAR(45),
    status ENUM('SUCCESS', 'FAILED') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 8. Tabel Pending Transactions (Intent Persistence for Recovery)
CREATE TABLE IF NOT EXISTS pending_transactions (
    txn_ref VARCHAR(50) PRIMARY KEY,
    from_email VARCHAR(100) NOT NULL,
    to_email VARCHAR(100) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING', 'COMMITTED', 'FAILED') DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_pending_from FOREIGN KEY (from_email) REFERENCES users(email),
    CONSTRAINT fk_pending_to FOREIGN KEY (to_email) REFERENCES users(email)
) ENGINE=InnoDB;

-- Indexes
CREATE INDEX idx_user_email ON users(email);
CREATE INDEX idx_currency_iso ON currencies(iso_code);
CREATE INDEX idx_exchange_lookup ON exchange_rates(base_currency_id, target_currency_id);
CREATE INDEX idx_acc_user ON accounts(user_id);
CREATE INDEX idx_acc_balance ON accounts(balance);
CREATE INDEX idx_ledger_txn ON ledger(txn_ref);
CREATE INDEX idx_ledger_acc_date ON ledger(account_id, created_at);
CREATE INDEX idx_audit_user_date ON audit_trail(user_id, created_at);
CREATE INDEX idx_audit_entity ON audit_trail(entity_type, entity_id);
