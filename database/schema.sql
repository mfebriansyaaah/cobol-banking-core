-- E-Wallet Enterprise Secure Database Schema
-- Target: MySQL 8.0 (InnoDB, utf8mb4)
-- Database: cobol_wallet
-- Purpose: Ensuring Financial Integrity and Strict Identity
-- Version: 1.1.0
-- Changelog:
--   v1.1.0 - Fixed index typo, added performance indexes on verification_logs
--   v1.0.0 - Initial schema: users, ledger, verification_logs tables

CREATE DATABASE IF NOT EXISTS cobol_wallet CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE cobol_wallet;

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

-- 7. Tabel Ledger (Refactored for Multi-Currency & Atomic Txns)
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

CREATE INDEX idx_ledger_txn ON ledger(txn_ref);
CREATE INDEX idx_ledger_acc_date ON ledger(account_id, created_at);

-- 3. Tabel Verification Logs (Anti-Spam & Tracking)
CREATE TABLE IF NOT EXISTS verification_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(100) NOT NULL,
    code VARCHAR(6) NOT NULL,
    purpose ENUM('SIGNUP', 'EMAIL_CHANGE') NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================
-- SECTION 4: Performance Indexes
-- ============================================================
-- Index: Speed up login and email lookup queries on users table
CREATE INDEX idx_user_email ON users(email);
-- 4. Tabel Currencies (Multi-currency Support)
CREATE TABLE IF NOT EXISTS currencies (
    currency_id INT AUTO_INCREMENT PRIMARY KEY,
    iso_code CHAR(3) NOT NULL UNIQUE,
    symbol VARCHAR(5) NOT NULL,
    precision INT DEFAULT 2,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO currencies (iso_code, symbol, precision) VALUES 
('USD', '$', 2),
('EUR', '€', 2),
('IDR', 'Rp', 0),
('GBP', '£', 2);

-- 5. Tabel Exchange Rates (Currency Conversion)
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

-- Default Rate: USD as Base
INSERT IGNORE INTO exchange_rates (base_currency_id, target_currency_id, exchange_rate) VALUES 
(1, 2, 0.92), -- USD to EUR
(1, 3, 15700.00), -- USD to IDR
(1, 4, 0.79); -- USD to GBP

-- 6. Tabel Accounts (User Financial Accounts)
CREATE TABLE IF NOT EXISTS accounts (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    currency_id INT NOT NULL,
    account_type ENUM('SAVINGS', 'CHECKING', 'INVESTMENT') DEFAULT 'SAVINGS',
    balance DECIMAL(18, 4) NOT NULL DEFAULT 0.0000,
    status ENUM('ACTIVE', 'FROZEN', 'CLOSED') DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_acc_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_acc_curr FOREIGN KEY (currency_id) REFERENCES currencies(currency_id),
    UNIQUE KEY unique_user_currency (user_id, currency_id)
) ENGINE=InnoDB;

CREATE INDEX idx_acc_user ON accounts(user_id);
CREATE INDEX idx_acc_balance ON accounts(balance);
