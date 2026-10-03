-- E-Wallet Secure Database Schema
-- Target: MySQL 8.0
-- Purpose: Ensuring Financial Integrity and Strict Identity

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
    balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Tabel Ledger (The Immutable Audit Trail)
-- Setiap perubahan saldo WAJIB ada di sini. 
CREATE TABLE IF NOT EXISTS ledger (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    type ENUM('CREDIT', 'DEBIT') NOT NULL,
    description VARCHAR(255) NOT NULL,
    txn_ref VARCHAR(50) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ledger_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

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

-- Indexing untuk performa
CREATE INDEX idx_user_email ON users(email);
CREATE INDEX idx_ledger_user_date ON ledger(user_id, created_at);

-- User untuk koneksi ODBC
-- CREATE USER IF NOT EXISTS 'cobol_user'@'localhost' IDENTIFIED BY 'cobol_pass';
-- GRANT ALL PRIVILEGES ON cobol_wallet.* TO 'cobol_user'@'localhost';
-- FLUSH PRIVILEGES;
