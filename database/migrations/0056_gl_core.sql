-- Phase 1: general-ledger core.
-- Chart of accounts, balanced manual journals, and trial balance.
-- The existing ledger/journal_entries remain the customer subledger; this is
-- the general ledger above it. Mapping subledger postings into GL accounts is
-- a later slice.

CREATE TABLE IF NOT EXISTS gl_account (
    account_code VARCHAR(20) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    account_type ENUM('ASSET','LIABILITY','EQUITY','REVENUE','EXPENSE') NOT NULL,
    normal_side ENUM('DEBIT','CREDIT') NOT NULL,
    parent_code VARCHAR(20) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_gl_account_parent FOREIGN KEY (parent_code)
        REFERENCES gl_account(account_code) ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS gl_journal (
    id INT AUTO_INCREMENT PRIMARY KEY,
    posting_date DATE NOT NULL,
    description VARCHAR(255) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    status ENUM('POSTED','REVERSED') NOT NULL DEFAULT 'POSTED',
    source VARCHAR(20) NOT NULL DEFAULT 'MANUAL',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gl_journal_date (posting_date, currency_code)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS gl_journal_line (
    id INT AUTO_INCREMENT PRIMARY KEY,
    journal_id INT NOT NULL,
    gl_account_code VARCHAR(20) NOT NULL,
    debit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    credit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    memo VARCHAR(255),
    CHECK (debit_amount >= 0 AND credit_amount >= 0),
    CHECK (debit_amount = 0 OR credit_amount = 0),
    CHECK (debit_amount > 0 OR credit_amount > 0),
    CONSTRAINT fk_gl_line_journal FOREIGN KEY (journal_id)
        REFERENCES gl_journal(id) ON DELETE CASCADE,
    CONSTRAINT fk_gl_line_account FOREIGN KEY (gl_account_code)
        REFERENCES gl_account(account_code) ON UPDATE CASCADE,
    INDEX idx_gl_line_journal (journal_id),
    INDEX idx_gl_line_account (gl_account_code)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS gl_audit (
    id INT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(32) NOT NULL,
    journal_id INT NULL,
    account_code VARCHAR(20) NULL,
    actor_email VARCHAR(100),
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gl_audit_account (account_code),
    INDEX idx_gl_audit_journal (journal_id)
) ENGINE=InnoDB;

INSERT IGNORE INTO gl_account (account_code, name, account_type, normal_side, is_active) VALUES
('1000', 'Cash', 'ASSET', 'DEBIT', TRUE),
('1100', 'Customer deposits', 'LIABILITY', 'CREDIT', TRUE),
('4000', 'Fee income', 'REVENUE', 'CREDIT', TRUE),
('5000', 'Operating expense', 'EXPENSE', 'DEBIT', TRUE);
