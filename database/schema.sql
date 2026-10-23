-- E-Wallet Enterprise Secure Database Schema
-- Target: MySQL 8.0 / MariaDB 11 (InnoDB, utf8mb4)
-- Purpose: Ensuring Financial Integrity and Strict Identity
-- Version: baseline-0037 (fresh-install snapshot; see the baseline block by
--   schema_migrations below, and docs/SCHEMA_POLICY.md for the change process)
-- Note: versioned changes live in database/migrations/NNN_*.sql; apply them
--       with database/migrate.sh. See docs/STATUS.md for schema details.
--   baseline-0037 - ledger exchange rate precision
--   baseline-0036 - dispute cases and messages
--   baseline-0035 - MFA backup codes and recovery requests
--   baseline-0034 - transactional notification outbox
--   baseline-0033 - dual-control designation and maker requests
--   baseline-0032 - reconciliation runs (immutable) and findings
--   baseline-0031 - account_holds, fee_schedule, FEE_INCOME/FEE enums
--   baseline-0030 - journal_entries header, ledger/audit journal link
--   baseline-0029 - FX lookup index restored (idx_exchange_lookup)
--   baseline-0028 - audit_trail append-only (no UPDATE)
--   baseline-0027 - ledger durability (append-only + archive triggers)
--   baseline-0024..0026 - audit actor attribution/integrity, ledger sender
--   baseline-0021..0023 - account lifecycle, refresh family limits, session metadata
--   baseline-0018..0020 - audit detail, pending id/archive
--   baseline-0014..0017 - MFA TOTP, per-sender idempotency key, reversals, ledger FX rate
--   baseline-0011..0013 - password-reset purpose, verification attempts, login lockout
--   baseline-0010 - audit_trail_archive (retention + archive)
--   baseline-0008..0009 - exchange_rates (re-introduced), revoked access tokens
--   baseline-0006..0007 - token_version; dropped unused schema (users.balance etc.)
--   baseline-0002..0005 - refresh_sessions, email FK cascades, session families
--   baseline-0001 - pending intents cascade on user delete
-- Changelog (pre-baseline era):
--   v1.7.0 - email FKs ON UPDATE CASCADE (email change with sessions/pending)
--   v1.6.0 - refresh_sessions table (refresh-token revocation by jti)
--   v1.5.0 - pending_transactions FKs ON DELETE CASCADE (idempotent transfers)
--   v1.4.0 - pending_transactions table for transfer intents
--   v1.3.0 - audit_trail + verification_logs used by the running core
--   v1.2.0 - Integrated Multi-Currency Accounts and Atomic Ledger
--   v1.1.0 - Fixed index typo, added performance indexes on verification_logs
--   v1.0.0 - Initial schema: users, ledger, verification_logs tables

-- 1. Table Users (Identity & Profile)
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    dob DATE NOT NULL,
    status ENUM('UNVERIFIED', 'VERIFIED', 'SUSPENDED', 'CLOSED') DEFAULT 'UNVERIFIED',
    role ENUM('USER', 'MANAGER', 'SUPER_ADMIN') DEFAULT 'USER',
    token_version INT NOT NULL DEFAULT 1,
    failed_logins INT NOT NULL DEFAULT 0,
    locked_until TIMESTAMP NULL DEFAULT NULL,
    last_login_at TIMESTAMP NULL DEFAULT NULL,
    dormant_notified_at TIMESTAMP NULL DEFAULT NULL,
    mfa_secret VARCHAR(64) NULL DEFAULT NULL,
    mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Table Currencies (Multi-currency Support)
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

-- 3. Table Exchange Rates (Currency Conversion)
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
(1, 2, 0.92),     -- USD to EUR
(1, 3, 15700.00), -- USD to IDR
(1, 4, 0.79);     -- USD to GBP

-- 4. Table Accounts (User Financial Accounts)
CREATE TABLE IF NOT EXISTS accounts (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    currency_id INT NOT NULL,
    account_type ENUM('SAVINGS', 'CHECKING', 'INVESTMENT', 'FEE_INCOME', 'FX_PNL') DEFAULT 'SAVINGS',  -- FEE_INCOME: bank-owned fee collection account (one active per currency); FX_PNL: bank-owned FX gain/loss account (one active per currency, D1)
    balance DECIMAL(18, 4) NOT NULL DEFAULT 0.0000 CHECK (balance >= 0),
    status ENUM('ACTIVE', 'FROZEN', 'CLOSED') DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_acc_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_acc_curr FOREIGN KEY (currency_id) REFERENCES currencies(currency_id),
    UNIQUE KEY unique_user_currency (user_id, currency_id),
    control_slot VARCHAR(32) GENERATED ALWAYS AS
      (CASE WHEN status = 'ACTIVE' AND account_type IN ('FX_PNL','FEE_INCOME')
            THEN CONCAT(currency_id, '/', account_type) ELSE NULL END) STORED,
    UNIQUE KEY uniq_active_control_acct (control_slot)
) ENGINE=InnoDB;

-- 5. Table Ledger (Refactored for Multi-Currency & Atomic Txns)
-- 5a. Journal header (one row per posting event: business date, source,
-- reference, initiator; legs and audit rows point at it)
CREATE TABLE IF NOT EXISTS journal_entries (
    journal_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    txn_ref VARCHAR(50) NOT NULL,
    source ENUM('TRANSFER','REVERSAL','FEE') NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    value_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_journal_ref (txn_ref)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS ledger;
CREATE TABLE IF NOT EXISTS ledger (
    ledger_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    txn_ref VARCHAR(50) NOT NULL,
    account_id INT NOT NULL,
    amount DECIMAL(18, 4) NOT NULL,
    type ENUM('CREDIT', 'DEBIT') NOT NULL,
    currency_id INT NOT NULL,
    from_email VARCHAR(100) NULL, -- the transfer's sender (txn_ref is unique per sender)
    description VARCHAR(255),
    exchange_rate DECIMAL(30, 18) NULL,
    journal_id BIGINT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_ledger_amount CHECK (amount >= 0),
    KEY idx_ledger_ref_sender (txn_ref, from_email),
    CONSTRAINT fk_ledger_acc FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE CASCADE,
    CONSTRAINT fk_ledger_curr FOREIGN KEY (currency_id) REFERENCES currencies(currency_id),
    CONSTRAINT fk_ledger_journal FOREIGN KEY (journal_id) REFERENCES gl_journal(id)
) ENGINE=InnoDB;

-- 6b. Immutable ledger archive (rows move here before an account is deleted)
CREATE TABLE IF NOT EXISTS ledger_archive (
    ledger_id BIGINT PRIMARY KEY,
    txn_ref VARCHAR(50) NOT NULL,
    account_id INT NOT NULL,
    amount DECIMAL(18, 4) NOT NULL,
    type ENUM('CREDIT', 'DEBIT') NOT NULL,
    currency_id INT NOT NULL,
    from_email VARCHAR(100) NULL,
    description VARCHAR(255),
    exchange_rate DECIMAL(30, 18) NULL,
    journal_id BIGINT NULL,
    created_at TIMESTAMP NULL,
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_ledger_archive_account (account_id)
) ENGINE=InnoDB;

-- 6. Table Verification Logs (Anti-Spam & Tracking)
CREATE TABLE IF NOT EXISTS verification_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(100) NOT NULL,
    code VARCHAR(6) NOT NULL,
    purpose ENUM('SIGNUP', 'EMAIL_CHANGE', 'PASSWORD_RESET', 'MFA_RECOVERY') NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    attempts INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 7. Table Audit Trail (Financial Compliance & Security)
CREATE TABLE IF NOT EXISTS audit_trail (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    actor_id INT NULL, -- who performed it; NULL = the subject performed it
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50), -- Example: 'ACCOUNT', 'LEDGER', 'USER'
    entity_id VARCHAR(50),   -- ID of the changed entity
    detail VARCHAR(255),     -- free-form context (e.g. transfer "to:amount:currency")
    journal_id BIGINT NULL, -- the journal_entries row for money movements
    status ENUM('SUCCESS', 'FAILED') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_audit_action (action),
    KEY idx_audit_actor (actor_id),
    CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 7b. Audit archive (immutable; rows move here past the retention window)
CREATE TABLE IF NOT EXISTS audit_trail_archive (
    audit_id BIGINT PRIMARY KEY,
    user_id INT NOT NULL,
    actor_id INT NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id VARCHAR(50),
    detail VARCHAR(255),
    status ENUM('SUCCESS', 'FAILED') NOT NULL,
    journal_id BIGINT NULL,
    created_at TIMESTAMP,
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_archive_created (created_at)
) ENGINE=InnoDB;

-- 8. Table Pending Transactions (Intent Persistence for Recovery)
CREATE TABLE IF NOT EXISTS pending_transactions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    txn_ref VARCHAR(50) NOT NULL,
    from_email VARCHAR(100) NOT NULL,
    to_email VARCHAR(100) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING', 'COMMITTED', 'FAILED') DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_pending_sender_ref (from_email, txn_ref),
    CONSTRAINT fk_pending_from FOREIGN KEY (from_email) REFERENCES users(email) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pending_to FOREIGN KEY (to_email) REFERENCES users(email) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 8b. Archive of pruned transfer intents (kept for traceability; no FKs so it
-- survives the users rows it references).
CREATE TABLE IF NOT EXISTS pending_transactions_archive (
    id BIGINT PRIMARY KEY,
    txn_ref VARCHAR(50) NOT NULL,
    from_email VARCHAR(100) NOT NULL,
    to_email VARCHAR(100) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING', 'COMMITTED', 'FAILED'),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_pending_archive_created (created_at)
) ENGINE=InnoDB;

-- 9. Table Transfer Reversals (one-time compensating reversal of a transfer)
CREATE TABLE IF NOT EXISTS transfer_reversals (
    orig_ref VARCHAR(50) NOT NULL,
    from_email VARCHAR(100) NOT NULL DEFAULT '', -- the original sender (ref is per-sender)
    actor_id INT NOT NULL,
    reason VARCHAR(100) NULL, -- reversal reason selecting the fee-refund policy (D2)
    reversed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (orig_ref, from_email),
    CONSTRAINT fk_reversal_actor FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 9b. Account holds (spendable-balance locks; PLACED rows reduce available)
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

-- 9c. Fee schedule (bank-owned per-currency flat fee; no row = no fee)
CREATE TABLE IF NOT EXISTS fee_schedule (
    currency_id INT PRIMARY KEY,
    fee_amount DECIMAL(18, 4) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_fee_amount CHECK (fee_amount >= 0),
    CONSTRAINT fk_fee_currency FOREIGN KEY (currency_id)
        REFERENCES currencies(currency_id)
) ENGINE=InnoDB;

-- 9d. Reversal fee-refund policy (D2: reason -> refund yes/no, data not code)
CREATE TABLE IF NOT EXISTS reversal_fee_policy (
    reason VARCHAR(100) PRIMARY KEY,
    refund_fee TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO reversal_fee_policy (reason, refund_fee) VALUES
('BANK_ERROR', 1),
('CUSTOMER_ERROR', 0);

-- 9e. Recorded reconciliation runs (immutable) and exception findings
CREATE TABLE IF NOT EXISTS reconciliation_runs (
    run_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    trigger_src ENUM('MANUAL','SCHEDULED') NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    status ENUM('CLEAN','MISMATCH') NOT NULL,
    mismatch_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_recon_created (created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reconciliation_findings (
    finding_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    run_id BIGINT NOT NULL,
    account_id INT NOT NULL,
    balance DECIMAL(18, 4) NOT NULL,
    ledger_sum DECIMAL(18, 4) NOT NULL,
    status ENUM('OPEN','ACKNOWLEDGED','RESOLVED') NOT NULL DEFAULT 'OPEN',
    owner_email VARCHAR(100) NULL,
    resolution_note VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    CONSTRAINT fk_finding_run FOREIGN KEY (run_id)
        REFERENCES reconciliation_runs(run_id),
    CONSTRAINT fk_finding_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id) ON DELETE CASCADE,
    KEY idx_finding_status (status)
) ENGINE=InnoDB;

-- 9e. Dual control: designation list plus maker requests
CREATE TABLE IF NOT EXISTS dual_control_operations (
    operation VARCHAR(50) PRIMARY KEY
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS maker_requests (
    request_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    operation VARCHAR(50) NOT NULL,
    target_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255) NULL,
    maker_email VARCHAR(100) NOT NULL,
    checker_email VARCHAR(100) NULL,
    state ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_at TIMESTAMP NULL,
    CONSTRAINT fk_maker_request_op FOREIGN KEY (operation)
        REFERENCES dual_control_operations(operation),
    KEY idx_maker_state (state)
) ENGINE=InnoDB;

-- 9f. Transactional notification outbox (worker-dispatched; codes never exposed)
CREATE TABLE IF NOT EXISTS notification_outbox (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    recipient VARCHAR(100) NOT NULL,
    purpose VARCHAR(32) NOT NULL,
    code VARCHAR(20) NOT NULL DEFAULT '',
    detail VARCHAR(255) NOT NULL DEFAULT '',
    state ENUM('PENDING','SENDING','SENT','FAILED','DEAD') NOT NULL DEFAULT 'PENDING',
    attempts INT NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMP NULL,
    last_error VARCHAR(255) NULL,
    claimed_by VARCHAR(100) NULL,
    claimed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP NULL,
    KEY idx_outbox_due (state, next_attempt_at, created_at)
) ENGINE=InnoDB;

-- 9g. MFA backup codes (hashed, single-use) and recovery requests
CREATE TABLE IF NOT EXISTS mfa_backup_codes (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    code_hash VARCHAR(255) NOT NULL,
    used BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_backup_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE,
    KEY idx_backup_user (user_id, used)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mfa_recovery_requests (
    request_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    state ENUM('PENDING','VERIFIED','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_at TIMESTAMP NULL,
    decided_by INT NULL,
    CONSTRAINT fk_recovery_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE,
    KEY idx_recovery_state (state)
) ENGINE=InnoDB;

-- 9h. Customer disputes (cases with controlled lifecycle, append-only notes)
CREATE TABLE IF NOT EXISTS dispute_cases (
    case_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    txn_ref VARCHAR(50) NULL,
    subject VARCHAR(100) NOT NULL,
    detail VARCHAR(100) NOT NULL,
    state ENUM('OPEN','ACKNOWLEDGED','RESOLVED','REJECTED') NOT NULL DEFAULT 'OPEN',
    assigned_to INT NULL,
    due_date DATE NULL,
    resolution VARCHAR(100) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    decided_at TIMESTAMP NULL,
    CONSTRAINT fk_dispute_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_dispute_assignee FOREIGN KEY (assigned_to)
        REFERENCES users(id) ON DELETE SET NULL,
    KEY idx_dispute_user_state (user_id, state)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dispute_messages (
    msg_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NOT NULL,
    author_id INT NOT NULL,
    body VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_msg_case FOREIGN KEY (case_id)
        REFERENCES dispute_cases(case_id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_author FOREIGN KEY (author_id)
        REFERENCES users(id) ON DELETE CASCADE,
    KEY idx_msg_case (case_id, msg_id)
) ENGINE=InnoDB;

DELIMITER //
CREATE TRIGGER IF NOT EXISTS trg_dispute_msg_no_update BEFORE UPDATE ON dispute_messages
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'dispute_messages is append-only (no UPDATE)';
END//

DELIMITER ;

-- 9l. Risk-based step-up policy (owner-controlled data). The core answers
-- STEP_UP_REQUIRED from this table; the gateway verifies the short-lived
-- proof. Email change and MFA disable are required by default; transfer is
-- catalogued but disabled until the owner sets a threshold.
CREATE TABLE IF NOT EXISTS step_up_policy (
    action VARCHAR(30) NOT NULL PRIMARY KEY,
    min_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    enabled BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

INSERT IGNORE INTO step_up_policy (action, min_amount, enabled) VALUES
    ('REQ_EMAIL_CHANGE', 0, TRUE),
    ('MFA_DISABLE', 0, TRUE),
    ('TRANSFER', 0, FALSE);

-- 9k. Password policy: bounded history and the owner-controlled deny list.
-- password_history keeps the last N password hashes a user set (the count is
-- PASSWORD_HISTORY_COUNT, 0 disables it); password_blocklist is keyed by the
-- SHA-256 hex of the lowercased value, so matching is case-insensitive. The
-- seed is a development placeholder; production supplies the list as data.
CREATE TABLE IF NOT EXISTS password_history (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_password_history_user (user_id, created_at),
    CONSTRAINT fk_password_history_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS password_blocklist (
    hash CHAR(64) NOT NULL PRIMARY KEY,
    note VARCHAR(100) NOT NULL DEFAULT ''
) ENGINE=InnoDB;

INSERT IGNORE INTO password_blocklist (hash, note) VALUES
    ('5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', 'password'),
    ('0b14d501a594442a01c6859541bcb3e8164d183d32937b851835442f69d5c94e', 'password1'),
    ('b3d17ebbe4f2b75d27b6309cfaae1487b667301a73951e7d523a039cd2dfe110', 'password12'),
    ('ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f', '12345678'),
    ('15e2b0d3c33891ebb0f1ef609ec419420c20e320ce94c65fbc8c3312448eb225', '123456789'),
    ('daaad6e5604e8e17bd9f108d91e26afe6281dac8fda0091040a7a6d7bd9b43b5', 'qwerty123'),
    ('1c8bfe8f801d79745c4631d09fff36c82aa37fc4cce4fc946683d7b336b63032', 'letmein'),
    ('e4ad93ca07acb8d908a3aa41e920ea4f4ef4f26e7f86cf8291c5db289780a5ae', 'iloveyou'),
    ('240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'admin123'),
    ('fcc3a23fc7232cc89c7cb0f23d8774fefb73d7dc2ab22e6a1b6b8b202b4dcc91', 'welcome1'),
    ('8f0e2f76e22b43e2855189877e7dc1e1e7d98c226c95db247cd1d547928334a9', 'passw0rd'),
    ('14f8f4bb8c0e79a02670a5fea5682da717a5b3d3dc7b1706f7a4bab9afae18c2', 'abc12345'),
    ('ee79976c9380d5e337fc1c095ece8c8f22f91f306ceeb161fa51fecede2c4ba1', '11111111'),
    ('6382deaf1f5dc6e792b76db4a4a7bf2ba468884e000b25e7928e621e27fb23cb', 'football'),
    ('e48443929f57ec4cb965d358a825849155b2828873c4ed2929fd711bc9f01347', 'monkey123');

-- 9j. Scoped permission catalog (capabilities as data, not code).
-- role_permissions maps each role to the permissions it holds; phase 1
-- reproduces the current behavior (SUPER_ADMIN holds every permission,
-- other roles hold none of the new ones), so granting anything further is
-- a Gate 0 owner decision, not a migration.
CREATE TABLE IF NOT EXISTS permissions (
    name VARCHAR(30) NOT NULL PRIMARY KEY,
    description VARCHAR(255) NOT NULL DEFAULT ''
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS role_permissions (
    role ENUM('USER','MANAGER','SUPER_ADMIN') NOT NULL,
    permission VARCHAR(30) NOT NULL,
    PRIMARY KEY (role, permission),
    CONSTRAINT fk_role_perm_perm FOREIGN KEY (permission)
        REFERENCES permissions(name) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 9i. Access review and attestation (periodic re-attestation of privileged accounts)
-- A review snapshots every MANAGER/SUPER_ADMIN account with the state that
-- matters to a reviewer. The items are evidence of that moment and carry no
-- foreign key to users, so deleting a reviewed account does not destroy the
-- review record.
CREATE TABLE IF NOT EXISTS access_reviews (
    review_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    state ENUM('OPEN','CLOSED') NOT NULL DEFAULT 'OPEN',
    opened_by VARCHAR(100) NOT NULL,
    closed_by VARCHAR(100) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP NULL,
    KEY idx_access_review_state (state)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS access_review_items (
    item_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    review_id BIGINT NOT NULL,
    email VARCHAR(100) NOT NULL,
    role VARCHAR(12) NOT NULL,
    account_status VARCHAR(20) NOT NULL,
    mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    last_login_at TIMESTAMP NULL,
    decision ENUM('PENDING','ATTESTED','REVOKED') NOT NULL DEFAULT 'PENDING',
    reviewer_email VARCHAR(100) NULL,
    note VARCHAR(255) NULL,
    decided_at TIMESTAMP NULL,
    CONSTRAINT fk_access_review_item_review FOREIGN KEY (review_id)
        REFERENCES access_reviews(review_id) ON DELETE CASCADE,
    KEY idx_access_review_item_review (review_id)
) ENGINE=InnoDB;

-- 10. Table Refresh Sessions (JWT refresh-token revocation by jti)
CREATE TABLE IF NOT EXISTS refresh_sessions (
    jti VARCHAR(50) PRIMARY KEY,
    family VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    revoked BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_agent VARCHAR(255) NULL,
    ip VARCHAR(45) NULL,
    last_seen_at TIMESTAMP NULL DEFAULT NULL,
    KEY idx_refresh_family (family),
    CONSTRAINT fk_refresh_user FOREIGN KEY (email) REFERENCES users(email) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 10b. Refresh-token families (absolute lifetime + rotation cap)
CREATE TABLE IF NOT EXISTS refresh_families (
    family VARCHAR(50) PRIMARY KEY,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    rotations INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_refresh_family_user FOREIGN KEY (email) REFERENCES users(email) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 10c. Known sign-in fingerprints (durable "seen this device before" record).
-- The first sighting enqueues a NEW_DEVICE outbox notice; a repeat does not.
-- No credential or code is stored here.
CREATE TABLE IF NOT EXISTS known_devices (
    email VARCHAR(100) NOT NULL,
    user_agent VARCHAR(255) NOT NULL DEFAULT '',
    ip VARCHAR(45) NOT NULL DEFAULT '',
    first_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (email, user_agent, ip)
) ENGINE=InnoDB;

-- 11. Access-token denylist (per-token revocation; complements users.token_version)
CREATE TABLE IF NOT EXISTS revoked_access_tokens (
    jti VARCHAR(50) PRIMARY KEY,
    email VARCHAR(100) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    revoked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_revoked_expires (expires_at),
    CONSTRAINT fk_revoked_user FOREIGN KEY (email) REFERENCES users(email) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 12. Table Schema Migrations (applied-migration tracking)
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(64) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 12a. Reference-data audit trail (7-day volume sprint, migration 0047)
CREATE TABLE IF NOT EXISTS reference_audit (
    id INT AUTO_INCREMENT PRIMARY KEY,
    entity VARCHAR(64) NOT NULL,
    entity_key VARCHAR(128) NOT NULL,
    action VARCHAR(32) NOT NULL,
    actor_email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_reference_audit_entity (entity, entity_key)
) ENGINE=InnoDB;

-- Reference-data tables folded from migration 0047
CREATE TABLE IF NOT EXISTS ref_country (
    code VARCHAR(2) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_holiday (
    code VARCHAR(10) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_channel (
    code VARCHAR(4) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_branch (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_cost_center (
    code VARCHAR(8) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_document_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_notification_template (
    code VARCHAR(8) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_status_code (
    code VARCHAR(4) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_rate_source (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_product_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_account_type (
    code VARCHAR(4) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_transaction_code (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_fee_code (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_charge_code (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_limit_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_limit_profile (
    code VARCHAR(8) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_settlement_account (
    code VARCHAR(8) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_clearing_account (
    code VARCHAR(8) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_suspense_account (
    code VARCHAR(8) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_rounding_rule (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_precision_rule (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_tax_code (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_language (
    code VARCHAR(3) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_timezone (
    code VARCHAR(5) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_country_region (
    code VARCHAR(4) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_currency_pair (
    code VARCHAR(7) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_holiday_calendar (
    code VARCHAR(8) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_document_template (
    code VARCHAR(8) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_notification_channel (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_audit_event_type (
    code VARCHAR(8) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_status_reason (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_account_status (
    code VARCHAR(4) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_payment_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_card_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_address_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_phone_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_email_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_review_state (
    code VARCHAR(4) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_report_group (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_city (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_province (
    code VARCHAR(4) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_district (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_postal_code (
    code VARCHAR(8) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_region (
    code VARCHAR(4) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_department (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_team (
    code VARCHAR(4) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_job_title (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_employee_grade (
    code VARCHAR(4) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_profit_center (
    code VARCHAR(8) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_loan_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_deposit_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_card_product (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_fee_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_charge_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_rate_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_tier (
    code VARCHAR(4) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_device_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_error_code (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_reason_code (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_document_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_template_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_queue (
    code VARCHAR(4) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_priority (
    code VARCHAR(4) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_sla_profile (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_calendar (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_business_day (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_cut_off_time (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_settlement_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_payment_channel (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_card_network (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_merchant_category (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_account_class (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_balance_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_entry_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_journal_source (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_posting_rule (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_gl_category (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_statement_format (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_report_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Reference-data tables folded from migration 0048 (batch 2)
CREATE TABLE IF NOT EXISTS ref_account_group (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_account_subtype (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_balance_class (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_ledger_class (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_journal_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_posting_frequency (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_accrual_basis (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_day_count_basis (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_interest_basis (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_compounding_method (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_rate_index (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_rate_benchmark (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_spread_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_fee_basis (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_fee_frequency (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_charge_basis (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_tax_basis (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_tax_jurisdiction (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_document_category (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_document_format (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_notification_priority (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_delivery_channel (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_message_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_template_scope (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_report_frequency (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_report_category (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_export_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_file_format (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_batch_group (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_batch_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_job_priority (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_schedule_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_calendar_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_timezone_region (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_country_group (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_region_group (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_branch_group (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_channel_class (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_user_segment (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_customer_segment (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Reference-data tables folded from migration 0049 (batch 3)
CREATE TABLE IF NOT EXISTS ref_account_purpose (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_account_ownership (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_account_restriction (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_account_feature (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_product_feature (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_product_group (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_product_family (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_product_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_pricing_tier (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_pricing_group (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_fee_waiver (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_fee_cap (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_fee_rounding (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_charge_group (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_tax_group (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_tax_rate_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_limit_basis (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_limit_frequency (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_limit_scope (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_transaction_class (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_transaction_group (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_transaction_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_transaction_channel (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_payment_scheme (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_payment_rail (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_settlement_cycle (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_clearing_cycle (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_cut_off_group (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_value_date_rule (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_posting_window (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_reversal_reason (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_adjustment_reason (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_dispute_reason (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_complaint_category (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_service_level (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_escalation_level (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_case_priority (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_case_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_workflow_action (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_workflow_role (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Reference-data tables folded from migration 0050 (batch 4)
CREATE TABLE IF NOT EXISTS ref_customer_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_customer_group (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_customer_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_customer_category (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_customer_industry (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_customer_occupation (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_customer_source (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_customer_channel (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_identity_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_identity_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_address_format (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_address_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_contact_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_contact_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_consent_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_consent_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_document_state (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_document_source (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_document_owner (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_verification_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_verification_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_review_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_review_outcome (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_approval_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_approval_outcome (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_request_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_request_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_task_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_task_priority (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_queue_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_queue_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_notification_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_notification_result (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_message_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_message_channel (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_event_type (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_event_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_audit_result (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_audit_source (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_audit_severity (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Reference-data table folded from migration 0051 (report layout)
CREATE TABLE IF NOT EXISTS ref_report_layout (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Reference-data tables folded from migration 0052 (batch 5)
CREATE TABLE IF NOT EXISTS ref_report_column (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_report_filter (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_report_parameter (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_report_scheduler (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_report_delivery (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_export_schedule (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_export_delivery (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_file_source (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_file_status (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_file_direction (
    code VARCHAR(6) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    num_val INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Phase 1: generic reference-data engine.
-- Replaces the per-entity generated CRUD with a type/value/version model:
-- effective dating, approval, translations, hierarchy, and audit.
-- The generated ref_core module stays in place until each domain is cut over.

CREATE TABLE IF NOT EXISTS ref_type (
    type_code VARCHAR(32) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    description VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_value (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type_code VARCHAR(32) NOT NULL,
    code VARCHAR(64) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_ref_value (type_code, code),
    CONSTRAINT fk_ref_value_type FOREIGN KEY (type_code)
        REFERENCES ref_type(type_code) ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_value_version (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ref_value_id INT NOT NULL,
    version_no INT NOT NULL,
    label VARCHAR(128) NOT NULL,
    attributes TEXT,
    status ENUM('DRAFT','ACTIVE','RETIRED') NOT NULL DEFAULT 'DRAFT',
    effective_from DATE NOT NULL,
    effective_to DATE NULL,
    approved_by VARCHAR(100),
    approved_at DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_ref_version (ref_value_id, version_no),
    CONSTRAINT fk_ref_version_value FOREIGN KEY (ref_value_id)
        REFERENCES ref_value(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_translation (
    ref_value_id INT NOT NULL,
    locale VARCHAR(10) NOT NULL,
    label VARCHAR(128) NOT NULL,
    PRIMARY KEY (ref_value_id, locale),
    CONSTRAINT fk_ref_translation_value FOREIGN KEY (ref_value_id)
        REFERENCES ref_value(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_hierarchy (
    parent_value_id INT NOT NULL,
    child_value_id INT NOT NULL,
    PRIMARY KEY (parent_value_id, child_value_id),
    CONSTRAINT fk_ref_hier_parent FOREIGN KEY (parent_value_id)
        REFERENCES ref_value(id) ON DELETE CASCADE,
    CONSTRAINT fk_ref_hier_child FOREIGN KEY (child_value_id)
        REFERENCES ref_value(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_engine_audit (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type_code VARCHAR(32) NOT NULL,
    value_code VARCHAR(64) NOT NULL,
    action VARCHAR(32) NOT NULL,
    actor_email VARCHAR(100),
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ref_engine_audit_value (type_code, value_code)
) ENGINE=InnoDB;

INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('currency', 'Currency', 'ISO 4217 currency codes', TRUE),
('country', 'Country', 'ISO 3166 country codes', TRUE),
('holiday', 'Holiday', 'Holiday calendar entries', TRUE),
('fee_code', 'Fee Code', 'Fee schedule codes', TRUE),
('limit_type', 'Limit Type', 'Limit definitions', TRUE),
('product_type', 'Product Type', 'Product catalog types', TRUE);

-- Phase 1 cutover: country and holiday reference domains.
-- The generic reference engine becomes the read/write source for these two
-- domains. The legacy generated tables remain as a read-only safety copy for
-- one release; a later cleanup migration may drop them.
--
-- The migration is idempotent: seeds use INSERT IGNORE, copies use NOT EXISTS,
-- and audit rows use NOT EXISTS.

INSERT IGNORE INTO ref_country (code, label, num_val, is_active) VALUES
('ID', 'Indonesia', 0, TRUE),
('US', 'United States', 0, TRUE);

INSERT IGNORE INTO ref_holiday (code, label, num_val, is_active) VALUES
('NEWYEAR', 'New Year', 0, TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'country', code FROM ref_country;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, c.label,
       CONCAT('num_val=', c.num_val, ';active=', c.is_active),
       IF(c.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_country c ON c.code = v.code
WHERE v.type_code = 'country'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'holiday', code FROM ref_holiday;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, h.label,
       CONCAT('num_val=', h.num_val, ';active=', h.is_active),
       IF(h.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_holiday h ON h.code = v.code
WHERE v.type_code = 'holiday'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'country', c.code, 'CUTOVER', 'migration', 'from ref_country'
FROM ref_country c
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'country' AND a.value_code = c.code AND a.action = 'CUTOVER'
);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'holiday', h.code, 'CUTOVER', 'migration', 'from ref_holiday'
FROM ref_holiday h
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'holiday' AND a.value_code = h.code AND a.action = 'CUTOVER'
);

-- Phase 1 cutover: fee_code, limit_type, and product_type reference domains.
-- The generic engine becomes the read/write source for these domains. The
-- legacy generated tables remain as a read-only safety copy for one release.
-- Idempotent: INSERT IGNORE and NOT EXISTS guards.

INSERT IGNORE INTO ref_fee_code (code, label, num_val, is_active) VALUES
('TRANSF', 'Transfer fee', 2500, TRUE),
('HOLDFE', 'Hold fee', 0, TRUE);

INSERT IGNORE INTO ref_limit_type (code, label, num_val, is_active) VALUES
('DAILYL', 'Daily limit', 0, TRUE),
('TXNLIM', 'Per-transaction limit', 0, TRUE);

INSERT IGNORE INTO ref_product_type (code, label, num_val, is_active) VALUES
('EWALLT', 'E-wallet', 0, TRUE),
('TRFPRD', 'Transfer', 0, TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_code', code FROM ref_fee_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, f.label,
       CONCAT('num_val=', f.num_val, ';active=', f.is_active),
       IF(f.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_code f ON f.code = v.code
WHERE v.type_code = 'fee_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'limit_type', code FROM ref_limit_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, l.label,
       CONCAT('num_val=', l.num_val, ';active=', l.is_active),
       IF(l.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_limit_type l ON l.code = v.code
WHERE v.type_code = 'limit_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'product_type', code FROM ref_product_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, p.label,
       CONCAT('num_val=', p.num_val, ';active=', p.is_active),
       IF(p.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_product_type p ON p.code = v.code
WHERE v.type_code = 'product_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_code', f.code, 'CUTOVER', 'migration', 'from ref_fee_code'
FROM ref_fee_code f
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_code' AND a.value_code = f.code AND a.action = 'CUTOVER'
);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'limit_type', l.code, 'CUTOVER', 'migration', 'from ref_limit_type'
FROM ref_limit_type l
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'limit_type' AND a.value_code = l.code AND a.action = 'CUTOVER'
);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'product_type', p.code, 'CUTOVER', 'migration', 'from ref_product_type'
FROM ref_product_type p
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'product_type' AND a.value_code = p.code AND a.action = 'CUTOVER'
);

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

-- Phase 1 Sprint 1: GL period control.
-- A period is YYYY-MM. Journals post only into an OPEN period.
CREATE TABLE IF NOT EXISTS gl_period (
    period_code CHAR(7) PRIMARY KEY,
    status ENUM('OPEN','CLOSED') NOT NULL DEFAULT 'OPEN',
    opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    closed_at DATETIME NULL,
    closed_by VARCHAR(100),
    CHECK (period_code REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$')
) ENGINE=InnoDB;

INSERT IGNORE INTO gl_period (period_code, status)
VALUES (DATE_FORMAT(CURDATE(), '%Y-%m'), 'OPEN');

-- Phase 1 Sprint 1 slice 2: batch/EOD foundation.
-- Job definitions, ordered steps, runs, run steps, control totals, and audit.

CREATE TABLE IF NOT EXISTS batch_job (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job_code VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    job_type ENUM('EOD','INTRADAY','REPORT','CLEANUP') NOT NULL,
    frequency ENUM('MANUAL','DAILY','WEEKLY','MONTHLY') NOT NULL DEFAULT 'MANUAL',
    schedule_time TIME NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    max_retries INT NOT NULL DEFAULT 3,
    timeout_seconds INT NOT NULL DEFAULT 3600,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (max_retries BETWEEN 0 AND 20),
    CHECK (timeout_seconds BETWEEN 1 AND 86400)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS batch_job_step (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job_id INT NOT NULL,
    step_no INT NOT NULL,
    step_code VARCHAR(40) NOT NULL,
    step_name VARCHAR(100) NOT NULL,
    max_retries INT NOT NULL DEFAULT 3,
    is_required BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_batch_job_step_no (job_id, step_no),
    UNIQUE KEY uq_batch_job_step_code (job_id, step_code),
    CONSTRAINT fk_batch_job_step_job FOREIGN KEY (job_id)
        REFERENCES batch_job(id) ON DELETE CASCADE,
    CHECK (step_no BETWEEN 1 AND 99),
    CHECK (max_retries BETWEEN 0 AND 20)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS batch_run (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job_id INT NOT NULL,
    business_date DATE NOT NULL,
    status ENUM('RUNNING','PAUSED','COMPLETED','FAILED','CANCELLED') NOT NULL DEFAULT 'RUNNING',
    attempt INT NOT NULL DEFAULT 1,
    checkpoint_key VARCHAR(100) NULL,
    checkpoint_value VARCHAR(100) NULL,
    processed_count BIGINT NOT NULL DEFAULT 0,
    success_count BIGINT NOT NULL DEFAULT 0,
    failed_count BIGINT NOT NULL DEFAULT 0,
    control_debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    control_credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    locked_by VARCHAR(100) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    version INT NOT NULL DEFAULT 0,
    UNIQUE KEY uq_batch_run_attempt (job_id, business_date, attempt),
    INDEX idx_batch_run_status (status, business_date),
    INDEX idx_batch_run_job (job_id, business_date),
    CONSTRAINT fk_batch_run_job FOREIGN KEY (job_id)
        REFERENCES batch_job(id),
    CHECK (attempt BETWEEN 1 AND 999),
    CHECK (processed_count >= 0 AND success_count >= 0 AND failed_count >= 0),
    CHECK (control_debit >= 0 AND control_credit >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS batch_run_step (
    id INT AUTO_INCREMENT PRIMARY KEY,
    run_id INT NOT NULL,
    step_no INT NOT NULL,
    step_code VARCHAR(40) NOT NULL,
    status ENUM('PENDING','RUNNING','COMPLETED','FAILED','SKIPPED') NOT NULL DEFAULT 'PENDING',
    attempt INT NOT NULL DEFAULT 0,
    processed_count BIGINT NOT NULL DEFAULT 0,
    success_count BIGINT NOT NULL DEFAULT 0,
    failed_count BIGINT NOT NULL DEFAULT 0,
    control_debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    control_credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    started_at DATETIME NULL,
    finished_at DATETIME NULL,
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_batch_run_step (run_id, step_no),
    CONSTRAINT fk_batch_run_step_run FOREIGN KEY (run_id)
        REFERENCES batch_run(id) ON DELETE CASCADE,
    CHECK (step_no BETWEEN 1 AND 99),
    CHECK (attempt BETWEEN 0 AND 999),
    CHECK (processed_count >= 0 AND success_count >= 0 AND failed_count >= 0),
    CHECK (control_debit >= 0 AND control_credit >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS batch_control_total (
    id INT AUTO_INCREMENT PRIMARY KEY,
    run_id INT NOT NULL,
    total_code VARCHAR(40) NOT NULL,
    expected_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    actual_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    variance DECIMAL(30,10) NOT NULL DEFAULT 0,
    status ENUM('MATCH','VARIANCE') NOT NULL DEFAULT 'MATCH',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_batch_control_total (run_id, total_code),
    CONSTRAINT fk_batch_control_run FOREIGN KEY (run_id)
        REFERENCES batch_run(id) ON DELETE CASCADE,
    CHECK (expected_amount >= 0 AND actual_amount >= 0 AND variance >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS batch_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id INT NULL,
    job_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_batch_audit_actor (actor_email, created_at),
    INDEX idx_batch_audit_run (run_id)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 3: report engine and import/export foundation.

CREATE TABLE IF NOT EXISTS report_template (
    id INT AUTO_INCREMENT PRIMARY KEY,
    template_code VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    report_type ENUM('TRIAL_BALANCE','STATEMENT','RECONCILIATION','CUSTOM') NOT NULL,
    output_format ENUM('CSV','FIXED','JSON') NOT NULL DEFAULT 'CSV',
    title VARCHAR(100) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_template_column (
    id INT AUTO_INCREMENT PRIMARY KEY,
    template_id INT NOT NULL,
    ordinal INT NOT NULL,
    header VARCHAR(100) NOT NULL,
    source_field VARCHAR(100) NOT NULL,
    width INT NOT NULL DEFAULT 20,
    align ENUM('LEFT','RIGHT','CENTER') NOT NULL DEFAULT 'LEFT',
    column_format ENUM('TEXT','AMOUNT','DATE','INTEGER') NOT NULL DEFAULT 'TEXT',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_report_column_ordinal (template_id, ordinal),
    CONSTRAINT fk_report_column_template FOREIGN KEY (template_id)
        REFERENCES report_template(id) ON DELETE CASCADE,
    CHECK (ordinal BETWEEN 1 AND 50),
    CHECK (width BETWEEN 1 AND 80)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_run (
    id INT AUTO_INCREMENT PRIMARY KEY,
    template_id INT NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    parameters VARCHAR(255) NOT NULL,
    row_count BIGINT NOT NULL DEFAULT 0,
    total_debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    total_credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    checksum VARCHAR(64) NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    version INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_report_run_status (status, started_at),
    INDEX idx_report_run_template (template_id, started_at),
    CONSTRAINT fk_report_run_template FOREIGN KEY (template_id)
        REFERENCES report_template(id),
    CHECK (row_count >= 0),
    CHECK (total_debit >= 0 AND total_credit >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_run_row (
    id INT AUTO_INCREMENT PRIMARY KEY,
    run_id INT NOT NULL,
    ordinal INT NOT NULL,
    row_data VARCHAR(500) NOT NULL,
    debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_report_row_ordinal (run_id, ordinal),
    CONSTRAINT fk_report_row_run FOREIGN KEY (run_id)
        REFERENCES report_run(id) ON DELETE CASCADE,
    CHECK (ordinal BETWEEN 1 AND 99999),
    CHECK (debit >= 0 AND credit >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    template_code VARCHAR(40) NULL,
    run_id INT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_report_audit_actor (actor_email, created_at),
    INDEX idx_report_audit_run (run_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS import_batch (
    id INT AUTO_INCREMENT PRIMARY KEY,
    batch_code VARCHAR(40) NOT NULL UNIQUE,
    source_name VARCHAR(100) NOT NULL,
    import_type ENUM('LEDGER','ACCOUNTS','REFERENCE','PAYMENTS') NOT NULL,
    status ENUM('STAGED','VALIDATING','VALIDATED','COMPLETED','FAILED') NOT NULL DEFAULT 'STAGED',
    total_rows BIGINT NOT NULL DEFAULT 0,
    valid_rows BIGINT NOT NULL DEFAULT 0,
    invalid_rows BIGINT NOT NULL DEFAULT 0,
    posted_rows BIGINT NOT NULL DEFAULT 0,
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    version INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_import_batch_status (status, created_at),
    INDEX idx_import_batch_type (import_type, created_at),
    CHECK (total_rows >= 0 AND valid_rows >= 0 AND invalid_rows >= 0 AND posted_rows >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS import_row (
    id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NOT NULL,
    row_no INT NOT NULL,
    raw_data VARCHAR(500) NOT NULL,
    status ENUM('STAGED','VALID','INVALID','POSTED','SKIPPED') NOT NULL DEFAULT 'STAGED',
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_import_row_no (batch_id, row_no),
    CONSTRAINT fk_import_row_batch FOREIGN KEY (batch_id)
        REFERENCES import_batch(id) ON DELETE CASCADE,
    CHECK (row_no BETWEEN 1 AND 99999)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS import_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    batch_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_import_audit_actor (actor_email, created_at),
    INDEX idx_import_audit_batch (batch_code)
) ENGINE=InnoDB;

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

-- Phase 1 Sprint 1 slice 5: statement archive and EOD job execution.

CREATE TABLE IF NOT EXISTS statement_run (
    id INT AUTO_INCREMENT PRIMARY KEY,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    currency_code CHAR(3) NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    account_count BIGINT NOT NULL DEFAULT 0,
    generated_count BIGINT NOT NULL DEFAULT 0,
    failed_count BIGINT NOT NULL DEFAULT 0,
    error_code VARCHAR(40) NULL,
    error_detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    version INT NOT NULL DEFAULT 0,
    INDEX idx_statement_run_status (status, period_end),
    CHECK (account_count >= 0 AND generated_count >= 0 AND failed_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_archive (
    id INT AUTO_INCREMENT PRIMARY KEY,
    run_id INT NOT NULL,
    account_email VARCHAR(100) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    opening_balance DECIMAL(30,10) NOT NULL DEFAULT 0,
    closing_balance DECIMAL(30,10) NOT NULL DEFAULT 0,
    total_debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    total_credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    row_count BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_statement_account (run_id, account_email, currency_code),
    CONSTRAINT fk_statement_archive_run FOREIGN KEY (run_id)
        REFERENCES statement_run(id) ON DELETE CASCADE,
    CHECK (row_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_archive_line (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    archive_id INT NOT NULL,
    line_no BIGINT NOT NULL,
    posting_date DATE NOT NULL,
    txn_ref VARCHAR(50) NOT NULL,
    source VARCHAR(20) NOT NULL,
    debit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    credit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    balance_after DECIMAL(30,10) NOT NULL DEFAULT 0,
    description VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_statement_line (archive_id, line_no),
    CONSTRAINT fk_statement_line_archive FOREIGN KEY (archive_id)
        REFERENCES statement_archive(id) ON DELETE CASCADE,
    CHECK (line_no >= 1),
    CHECK (debit_amount >= 0 AND credit_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id INT NULL,
    account_email VARCHAR(100) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_statement_audit_actor (actor_email, created_at),
    INDEX idx_statement_audit_run (run_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS eod_job_run (
    id INT AUTO_INCREMENT PRIMARY KEY,
    business_date DATE NOT NULL,
    job_code ENUM('HOLD_EXPIRY','DORMANT_MARK','DORMANT_SUSPEND','RECON','STATEMENT') NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    processed_count BIGINT NOT NULL DEFAULT 0,
    detail VARCHAR(255) NULL,
    error_code VARCHAR(40) NULL,
    actor_email VARCHAR(100) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    UNIQUE KEY uq_eod_job_date (business_date, job_code),
    INDEX idx_eod_job_status (status, business_date),
    CHECK (processed_count >= 0)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 6: notification templates/preferences.

CREATE TABLE IF NOT EXISTS notification_template (
    template_code VARCHAR(40) PRIMARY KEY,
    purpose VARCHAR(32) NOT NULL,
    channel ENUM('EMAIL','INAPP') NOT NULL DEFAULT 'EMAIL',
    subject VARCHAR(160) NOT NULL,
    body VARCHAR(1000) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_notification_template_purpose (purpose, channel, enabled)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notification_preference (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_email VARCHAR(100) NOT NULL,
    purpose VARCHAR(32) NOT NULL,
    channel ENUM('EMAIL','INAPP') NOT NULL DEFAULT 'EMAIL',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_notification_preference (user_email, purpose, channel),
    INDEX idx_notification_preference_user (user_email, enabled)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notification_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    template_code VARCHAR(40) NULL,
    user_email VARCHAR(100) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notification_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 7: payment policy and reconciliation reporting.

CREATE TABLE IF NOT EXISTS payment_policy (
    currency_code CHAR(3) PRIMARY KEY,
    max_per_txn DECIMAL(30,10) NOT NULL DEFAULT 0,
    daily_limit DECIMAL(30,10) NOT NULL DEFAULT 0,
    daily_count INT NOT NULL DEFAULT 0,
    hold_threshold DECIMAL(30,10) NOT NULL DEFAULT 0,
    hold_percent DECIMAL(5,2) NOT NULL DEFAULT 0,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (max_per_txn >= 0 AND daily_limit >= 0 AND daily_count >= 0),
    CHECK (hold_threshold >= 0),
    CHECK (hold_percent BETWEEN 0 AND 100)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payment_profile (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_email VARCHAR(100) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    daily_limit DECIMAL(30,10) NOT NULL DEFAULT 0,
    daily_count INT NOT NULL DEFAULT 0,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_payment_profile (user_email, currency_code),
    CHECK (daily_limit >= 0 AND daily_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payment_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    user_email VARCHAR(100) NULL,
    currency_code CHAR(3) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_payment_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS recon_note (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    finding_id BIGINT NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    note VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_recon_note_finding FOREIGN KEY (finding_id)
        REFERENCES reconciliation_findings(finding_id) ON DELETE CASCADE,
    INDEX idx_recon_note_finding (finding_id, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS recon_sla_policy (
    policy_code VARCHAR(32) PRIMARY KEY,
    age_hours INT NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (age_hours BETWEEN 1 AND 8760)
) ENGINE=InnoDB;

INSERT IGNORE INTO recon_sla_policy (policy_code, age_hours, enabled, updated_by)
VALUES ('DEFAULT', 24, TRUE, 'SYSTEM');

-- Phase 1 Sprint 1 slice 8: import posting and report delivery.

ALTER TABLE import_row
    ADD COLUMN IF NOT EXISTS parsed_account VARCHAR(20) NULL,
    ADD COLUMN IF NOT EXISTS debit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS credit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    ADD INDEX IF NOT EXISTS idx_import_row_parsed (batch_id, parsed_account);

CREATE TABLE IF NOT EXISTS import_posting (
    id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NOT NULL,
    journal_id INT NOT NULL,
    posted_rows BIGINT NOT NULL DEFAULT 0,
    total_debit DECIMAL(30,10) NOT NULL DEFAULT 0,
    total_credit DECIMAL(30,10) NOT NULL DEFAULT 0,
    status ENUM('POSTED','REVERSED') NOT NULL DEFAULT 'POSTED',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_import_posting_batch (batch_id),
    CONSTRAINT fk_import_posting_batch FOREIGN KEY (batch_id)
        REFERENCES import_batch(id) ON DELETE CASCADE,
    CONSTRAINT fk_import_posting_journal FOREIGN KEY (journal_id)
        REFERENCES gl_journal(id),
    CHECK (posted_rows >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_layout (
    id INT AUTO_INCREMENT PRIMARY KEY,
    template_id INT NOT NULL,
    page_width INT NOT NULL DEFAULT 132,
    page_length INT NOT NULL DEFAULT 66,
    header_text VARCHAR(100) NOT NULL DEFAULT '',
    footer_text VARCHAR(100) NOT NULL DEFAULT '',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_report_layout_template (template_id),
    CONSTRAINT fk_report_layout_template FOREIGN KEY (template_id)
        REFERENCES report_template(id) ON DELETE CASCADE,
    CHECK (page_width BETWEEN 40 AND 240),
    CHECK (page_length BETWEEN 10 AND 200)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS report_scheduler_run;
DROP TABLE IF EXISTS report_scheduler_audit;
DROP TABLE IF EXISTS report_scheduler;
CREATE TABLE IF NOT EXISTS report_scheduler (
    id INT AUTO_INCREMENT PRIMARY KEY,
    template_code VARCHAR(40) NOT NULL,
    frequency ENUM('DAILY','WEEKLY','MONTHLY') NOT NULL,
    schedule_time TIME NOT NULL,
    output_format ENUM('CSV','FIXED','JSON') NOT NULL DEFAULT 'CSV',
    currency_code CHAR(3) NOT NULL DEFAULT 'IDR',
    recipient VARCHAR(100) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    last_run_at DATETIME NULL,
    next_run_date DATE NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_report_scheduler_due (enabled, next_run_date),
    CHECK (recipient LIKE '%@%')
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 9: dispute operations and retained exports.

ALTER TABLE dispute_cases
    ADD COLUMN IF NOT EXISTS priority ENUM('LOW','NORMAL','HIGH','URGENT')
        NOT NULL DEFAULT 'NORMAL' AFTER state,
    ADD INDEX IF NOT EXISTS idx_dispute_priority (priority, state, due_date);

CREATE TABLE IF NOT EXISTS dispute_sla_policy (
    priority ENUM('LOW','NORMAL','HIGH','URGENT') PRIMARY KEY,
    response_hours INT NOT NULL DEFAULT 24,
    resolution_hours INT NOT NULL DEFAULT 72,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (response_hours BETWEEN 1 AND 8760),
    CHECK (resolution_hours BETWEEN 1 AND 8760),
    CHECK (response_hours <= resolution_hours)
) ENGINE=InnoDB;

INSERT IGNORE INTO dispute_sla_policy
    (priority, response_hours, resolution_hours, enabled, updated_by)
VALUES
    ('LOW', 72, 168, TRUE, 'SYSTEM'),
    ('NORMAL', 24, 72, TRUE, 'SYSTEM'),
    ('HIGH', 8, 24, TRUE, 'SYSTEM'),
    ('URGENT', 2, 8, TRUE, 'SYSTEM');

CREATE TABLE IF NOT EXISTS dispute_assignment (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NOT NULL,
    from_user_id INT NULL,
    to_user_id INT NULL,
    assigned_by VARCHAR(100) NOT NULL,
    note VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_dispute_assignment_case FOREIGN KEY (case_id)
        REFERENCES dispute_cases(case_id) ON DELETE CASCADE,
    CONSTRAINT fk_dispute_assignment_from FOREIGN KEY (from_user_id)
        REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_dispute_assignment_to FOREIGN KEY (to_user_id)
        REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_dispute_assignment_case (case_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dispute_ops_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    case_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_dispute_ops_actor (actor_email, created_at),
    INDEX idx_dispute_ops_case (case_id, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS export_archive (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    export_type ENUM('REPORT','IMPORT') NOT NULL,
    source_code VARCHAR(64) NOT NULL,
    format ENUM('CSV','JSON','FIXED') NOT NULL DEFAULT 'CSV',
    content LONGTEXT NOT NULL,
    checksum CHAR(64) NOT NULL,
    row_count BIGINT NOT NULL DEFAULT 0,
    byte_count BIGINT NOT NULL DEFAULT 0,
    retention_days INT NOT NULL DEFAULT 365,
    expires_at DATE NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_export_archive_source (export_type, source_code, format),
    INDEX idx_export_archive_source (export_type, source_code),
    INDEX idx_export_archive_expiry (expires_at),
    CHECK (retention_days BETWEEN 1 AND 3650),
    CHECK (row_count >= 0 AND byte_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS export_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    archive_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_export_audit_actor (actor_email, created_at),
    INDEX idx_export_audit_archive (archive_id)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 10: reconciliation auto-assignment and operations alerts.

CREATE TABLE IF NOT EXISTS recon_assignment_rule (
    rule_code VARCHAR(40) PRIMARY KEY,
    owner_email VARCHAR(100) NOT NULL,
    status_filter ENUM('ANY','OPEN','ACKNOWLEDGED') NOT NULL DEFAULT 'ANY',
    min_age_hours INT NOT NULL DEFAULT 0,
    priority INT NOT NULL DEFAULT 100,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_recon_rule_match (enabled, status_filter, min_age_hours, priority),
    CHECK (min_age_hours BETWEEN 0 AND 8760),
    CHECK (priority BETWEEN 1 AND 999)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS recon_assignment (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    finding_id BIGINT NOT NULL,
    from_owner VARCHAR(100) NULL,
    to_owner VARCHAR(100) NOT NULL,
    rule_code VARCHAR(40) NULL,
    assigned_by VARCHAR(100) NOT NULL,
    note VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_recon_assignment_finding FOREIGN KEY (finding_id)
        REFERENCES reconciliation_findings(finding_id) ON DELETE CASCADE,
    INDEX idx_recon_assignment_finding (finding_id, id),
    INDEX idx_recon_assignment_owner (to_owner, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ops_alert (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alert_type VARCHAR(32) NOT NULL,
    severity ENUM('INFO','WARNING','CRITICAL') NOT NULL DEFAULT 'WARNING',
    source_key VARCHAR(120) NOT NULL,
    title VARCHAR(160) NOT NULL,
    detail VARCHAR(255) NOT NULL DEFAULT '',
    state ENUM('OPEN','ACKNOWLEDGED','RESOLVED') NOT NULL DEFAULT 'OPEN',
    owner_email VARCHAR(100) NULL,
    acknowledged_at DATETIME NULL,
    resolved_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_ops_alert_source (source_key),
    INDEX idx_ops_alert_state (state, severity, created_at),
    INDEX idx_ops_alert_type (alert_type, state)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ops_alert_event (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alert_id BIGINT NOT NULL,
    event ENUM('RAISED','ACKNOWLEDGED','RESOLVED','NOTE','REOPENED') NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    note VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ops_alert_event FOREIGN KEY (alert_id)
        REFERENCES ops_alert(id) ON DELETE CASCADE,
    INDEX idx_ops_alert_event (alert_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ops_alert_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    alert_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ops_alert_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 12: schedule run history and statement reconciliation.

CREATE TABLE IF NOT EXISTS report_scheduler_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    schedule_id INT NOT NULL,
    report_run_id INT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    period_from DATE NULL,
    period_to DATE NULL,
    currency_code CHAR(3) NULL,
    output_format ENUM('CSV','FIXED','JSON') NULL,
    error_detail VARCHAR(255) NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    CONSTRAINT fk_schedule_run_schedule FOREIGN KEY (schedule_id)
        REFERENCES report_scheduler(id) ON DELETE CASCADE,
    CONSTRAINT fk_schedule_run_report FOREIGN KEY (report_run_id)
        REFERENCES report_run(id) ON DELETE SET NULL,
    INDEX idx_schedule_run_status (status, started_at),
    INDEX idx_schedule_run_schedule (schedule_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_recon_run (
    id INT AUTO_INCREMENT PRIMARY KEY,
    statement_run_id INT NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    line_count BIGINT NOT NULL DEFAULT 0,
    matched_count BIGINT NOT NULL DEFAULT 0,
    unmatched_count BIGINT NOT NULL DEFAULT 0,
    mismatch_count BIGINT NOT NULL DEFAULT 0,
    error_detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    CONSTRAINT fk_stmt_recon_run_statement FOREIGN KEY (statement_run_id)
        REFERENCES statement_run(id) ON DELETE CASCADE,
    INDEX idx_stmt_recon_status (status, started_at),
    CHECK (line_count >= 0 AND matched_count >= 0 AND unmatched_count >= 0 AND mismatch_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_recon_item (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    run_id INT NOT NULL,
    statement_line_id BIGINT NOT NULL,
    account_id INT NULL,
    txn_ref VARCHAR(50) NOT NULL,
    posting_date DATE NOT NULL,
    amount DECIMAL(30,10) NOT NULL,
    matched_ledger_id BIGINT NULL,
    match_status ENUM('MATCHED','UNMATCHED','MISMATCH') NOT NULL,
    detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_stmt_item_run FOREIGN KEY (run_id)
        REFERENCES statement_recon_run(id) ON DELETE CASCADE,
    CONSTRAINT fk_stmt_item_line FOREIGN KEY (statement_line_id)
        REFERENCES statement_archive_line(id) ON DELETE CASCADE,
    CONSTRAINT fk_stmt_item_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id) ON DELETE SET NULL,
    CONSTRAINT fk_stmt_item_ledger FOREIGN KEY (matched_ledger_id)
        REFERENCES ledger(ledger_id) ON DELETE SET NULL,
    UNIQUE KEY uq_stmt_item_line (run_id, statement_line_id),
    INDEX idx_stmt_item_status (run_id, match_status)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 13: standing payment instructions and on-call routing.

CREATE TABLE IF NOT EXISTS payment_instruction (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    instruction_code VARCHAR(40) NOT NULL UNIQUE,
    from_email VARCHAR(100) NOT NULL,
    to_email VARCHAR(100) NOT NULL,
    amount DECIMAL(30,10) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    frequency ENUM('ONCE','DAILY','WEEKLY','MONTHLY') NOT NULL DEFAULT 'ONCE',
    next_run_date DATE NOT NULL DEFAULT '1970-01-01',
    end_date DATE NULL,
    status ENUM('ACTIVE','PAUSED','CANCELLED','COMPLETED') NOT NULL DEFAULT 'ACTIVE',
    last_run_at DATETIME NULL,
    last_txn_ref VARCHAR(50) NULL,
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_payment_instruction_due (status, next_run_date),
    INDEX idx_payment_instruction_from (from_email, status),
    CHECK (amount > 0),
    CHECK (end_date IS NULL OR end_date >= next_run_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payment_instruction_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    instruction_id BIGINT NOT NULL,
    status ENUM('COMPLETED','FAILED') NOT NULL,
    txn_ref VARCHAR(50) NULL,
    error_detail VARCHAR(255) NULL,
    run_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100) NOT NULL,
    CONSTRAINT fk_payment_instruction_run FOREIGN KEY (instruction_id)
        REFERENCES payment_instruction(id) ON DELETE CASCADE,
    INDEX idx_payment_instruction_run (instruction_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS oncall_rotation (
    id INT AUTO_INCREMENT PRIMARY KEY,
    rotation_code VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS oncall_shift (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rotation_id INT NOT NULL,
    user_email VARCHAR(100) NOT NULL,
    starts_at DATETIME NOT NULL,
    ends_at DATETIME NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_oncall_shift_rotation FOREIGN KEY (rotation_id)
        REFERENCES oncall_rotation(id) ON DELETE CASCADE,
    INDEX idx_oncall_shift_window (rotation_id, starts_at, ends_at),
    CHECK (ends_at > starts_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS escalation_policy (
    id INT AUTO_INCREMENT PRIMARY KEY,
    policy_code VARCHAR(40) NOT NULL UNIQUE,
    alert_type VARCHAR(32) NOT NULL,
    severity_min ENUM('INFO','WARNING','CRITICAL') NOT NULL DEFAULT 'WARNING',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS escalation_step (
    id INT AUTO_INCREMENT PRIMARY KEY,
    policy_id INT NOT NULL,
    step_no INT NOT NULL,
    delay_minutes INT NOT NULL DEFAULT 0,
    target_email VARCHAR(100) NOT NULL,
    channel ENUM('EMAIL','PAGE') NOT NULL DEFAULT 'EMAIL',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_escalation_step_policy FOREIGN KEY (policy_id)
        REFERENCES escalation_policy(id) ON DELETE CASCADE,
    UNIQUE KEY uq_escalation_step (policy_id, step_no),
    CHECK (step_no BETWEEN 1 AND 20),
    CHECK (delay_minutes BETWEEN 0 AND 1440)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS oncall_page (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alert_id BIGINT NOT NULL,
    policy_id INT NULL,
    step_no INT NOT NULL DEFAULT 1,
    target_email VARCHAR(100) NOT NULL,
    status ENUM('PAGED','ACKED','RESOLVED','FAILED') NOT NULL DEFAULT 'PAGED',
    detail VARCHAR(255) NULL,
    paged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acked_at DATETIME NULL,
    resolved_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    CONSTRAINT fk_oncall_page_policy FOREIGN KEY (policy_id)
        REFERENCES escalation_policy(id) ON DELETE SET NULL,
    INDEX idx_oncall_page_status (status, paged_at),
    INDEX idx_oncall_page_alert (alert_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS oncall_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    page_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_oncall_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 14: audit analytics and import reconciliation.

CREATE TABLE IF NOT EXISTS audit_analytics_snapshot (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    snapshot_date DATE NOT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    event_count BIGINT NOT NULL DEFAULT 0,
    failure_count BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_audit_snapshot (snapshot_date, action, actor_email),
    CHECK (event_count >= 0 AND failure_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS import_recon_run (
    id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    row_count BIGINT NOT NULL DEFAULT 0,
    matched_count BIGINT NOT NULL DEFAULT 0,
    unmatched_count BIGINT NOT NULL DEFAULT 0,
    mismatch_count BIGINT NOT NULL DEFAULT 0,
    error_detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    CONSTRAINT fk_import_recon_batch FOREIGN KEY (batch_id)
        REFERENCES import_batch(id) ON DELETE CASCADE,
    INDEX idx_import_recon_status (status, started_at),
    CHECK (row_count >= 0 AND matched_count >= 0 AND unmatched_count >= 0 AND mismatch_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS import_recon_item (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    run_id INT NOT NULL,
    import_row_id INT NOT NULL,
    account_code VARCHAR(20) NOT NULL,
    debit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    credit_amount DECIMAL(30,10) NOT NULL DEFAULT 0,
    matched_journal_id INT NULL,
    match_status ENUM('MATCHED','UNMATCHED','MISMATCH') NOT NULL,
    detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_import_recon_item_run FOREIGN KEY (run_id)
        REFERENCES import_recon_run(id) ON DELETE CASCADE,
    CONSTRAINT fk_import_recon_item_row FOREIGN KEY (import_row_id)
        REFERENCES import_row(id) ON DELETE CASCADE,
    CONSTRAINT fk_import_recon_item_journal FOREIGN KEY (matched_journal_id)
        REFERENCES gl_journal(id) ON DELETE SET NULL,
    UNIQUE KEY uq_import_recon_item (run_id, import_row_id),
    INDEX idx_import_recon_status (run_id, match_status)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 15: reconciliation exceptions and dispute notifications.

CREATE TABLE IF NOT EXISTS recon_exception (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    finding_id BIGINT NULL,
    exception_code VARCHAR(40) NOT NULL,
    priority ENUM('LOW','NORMAL','HIGH','URGENT') NOT NULL DEFAULT 'NORMAL',
    owner_email VARCHAR(100) NULL,
    state ENUM('OPEN','ACKNOWLEDGED','IN_PROGRESS','RESOLVED','REJECTED','CLOSED') NOT NULL DEFAULT 'OPEN',
    due_date DATE NULL,
    resolution VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    resolved_at DATETIME NULL,
    CONSTRAINT fk_recon_exception_finding FOREIGN KEY (finding_id)
        REFERENCES reconciliation_findings(finding_id) ON DELETE SET NULL,
    INDEX idx_recon_exception_state (state, priority, due_date),
    INDEX idx_recon_exception_owner (owner_email, state)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS recon_exception_note (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    exception_id BIGINT NOT NULL,
    author_email VARCHAR(100) NOT NULL,
    body VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_recon_exception_note FOREIGN KEY (exception_id)
        REFERENCES recon_exception(id) ON DELETE CASCADE,
    INDEX idx_recon_exception_note (exception_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS recon_exception_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    exception_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_recon_exception_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dispute_notification_template (
    template_code VARCHAR(40) PRIMARY KEY,
    purpose VARCHAR(32) NOT NULL,
    channel ENUM('EMAIL','INAPP') NOT NULL DEFAULT 'EMAIL',
    subject VARCHAR(160) NOT NULL,
    body VARCHAR(1000) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_dispute_notification_template (purpose, channel, enabled)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dispute_notification (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NOT NULL,
    recipient VARCHAR(100) NOT NULL,
    purpose VARCHAR(32) NOT NULL,
    template_code VARCHAR(40) NULL,
    channel ENUM('EMAIL','INAPP') NOT NULL DEFAULT 'EMAIL',
    state ENUM('PENDING','SENDING','SENT','FAILED','DEAD') NOT NULL DEFAULT 'PENDING',
    attempts INT NOT NULL DEFAULT 0,
    last_error VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at DATETIME NULL,
    CONSTRAINT fk_dispute_notification_case FOREIGN KEY (case_id)
        REFERENCES dispute_cases(case_id) ON DELETE CASCADE,
    CONSTRAINT fk_dispute_notification_template FOREIGN KEY (template_code)
        REFERENCES dispute_notification_template(template_code) ON DELETE SET NULL,
    INDEX idx_dispute_notification_state (state, created_at),
    INDEX idx_dispute_notification_case (case_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dispute_notification_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    case_id BIGINT NULL,
    notification_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_dispute_notification_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 16: export download tokens and alert escalation.

CREATE TABLE IF NOT EXISTS export_download_token (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    token VARCHAR(64) NOT NULL UNIQUE,
    archive_id BIGINT NOT NULL,
    expires_at DATETIME NOT NULL,
    download_count BIGINT NOT NULL DEFAULT 0,
    max_downloads BIGINT NOT NULL DEFAULT 5,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_export_download_archive FOREIGN KEY (archive_id)
        REFERENCES export_archive(id) ON DELETE CASCADE,
    INDEX idx_export_download_expiry (expires_at),
    CHECK (max_downloads BETWEEN 1 AND 1000)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS alert_escalation_policy (
    policy_code VARCHAR(40) PRIMARY KEY,
    alert_type VARCHAR(32) NOT NULL,
    severity_min ENUM('INFO','WARNING','CRITICAL') NOT NULL DEFAULT 'WARNING',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS alert_escalation_step (
    id INT AUTO_INCREMENT PRIMARY KEY,
    policy_code VARCHAR(40) NOT NULL,
    step_no INT NOT NULL,
    delay_minutes INT NOT NULL DEFAULT 0,
    target_email VARCHAR(100) NOT NULL,
    channel ENUM('EMAIL','PAGE') NOT NULL DEFAULT 'EMAIL',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_alert_escalation_step_policy FOREIGN KEY (policy_code)
        REFERENCES alert_escalation_policy(policy_code) ON DELETE CASCADE,
    UNIQUE KEY uq_alert_escalation_step (policy_code, step_no),
    CHECK (step_no BETWEEN 1 AND 20),
    CHECK (delay_minutes BETWEEN 0 AND 1440)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS alert_escalation_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alert_id BIGINT NOT NULL,
    policy_code VARCHAR(40) NOT NULL,
    step_no INT NOT NULL,
    target_email VARCHAR(100) NOT NULL,
    status ENUM('PENDING','PAGED','ACKED','RESOLVED','FAILED') NOT NULL DEFAULT 'PENDING',
    detail VARCHAR(255) NULL,
    paged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acked_at DATETIME NULL,
    resolved_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    INDEX idx_alert_escalation_status (status, paged_at),
    INDEX idx_alert_escalation_alert (alert_id, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS alert_escalation_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_alert_escalation_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 17: audit drill-down queries and compliance export packages.

CREATE TABLE IF NOT EXISTS audit_drilldown_query (
    query_code VARCHAR(40) PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    filter_spec VARCHAR(255) NOT NULL,
    saved_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_drilldown_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    query_code VARCHAR(40) NOT NULL,
    row_count BIGINT NOT NULL DEFAULT 0,
    digest CHAR(64) NULL,
    executed_by VARCHAR(100) NOT NULL,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_adr_run_query (query_code, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_drilldown_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    query_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_adr_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compliance_export_package (
    package_code VARCHAR(40) PRIMARY KEY,
    framework ENUM('SOX','GDPR','PCI','AML') NOT NULL,
    title VARCHAR(120) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    status ENUM('DRAFT','SEALED','ATTESTED','REVOKED') NOT NULL DEFAULT 'DRAFT',
    checksum CHAR(64) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sealed_at DATETIME NULL,
    attested_by VARCHAR(100) NULL,
    attested_at DATETIME NULL,
    revoke_reason VARCHAR(255) NULL,
    CHECK (period_end >= period_start)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compliance_export_item (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    package_code VARCHAR(40) NOT NULL,
    item_type ENUM('AUDIT_QUERY','EXPORT_ARCHIVE','REPORT_RUN') NOT NULL,
    ref_id VARCHAR(64) NOT NULL,
    included BOOLEAN NOT NULL DEFAULT TRUE,
    detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cex_item_package FOREIGN KEY (package_code)
        REFERENCES compliance_export_package(package_code) ON DELETE CASCADE,
    UNIQUE KEY uq_cex_item (package_code, item_type, ref_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compliance_export_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    package_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_cex_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 18: payment holds and on-call delivery tracking.

CREATE TABLE IF NOT EXISTS payment_hold (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    currency CHAR(3) NOT NULL,
    status ENUM('ACTIVE','CAPTURED','RELEASED','EXPIRED','FAILED') NOT NULL DEFAULT 'ACTIVE',
    expires_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    captured_at DATETIME NULL,
    released_at DATETIME NULL,
    CONSTRAINT fk_payment_hold_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id) ON DELETE CASCADE,
    INDEX idx_payment_hold_status (status, expires_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payment_hold_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    hold_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_payment_hold_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS oncall_delivery (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    page_id BIGINT NOT NULL,
    channel ENUM('EMAIL','PAGE') NOT NULL,
    target_email VARCHAR(100) NOT NULL,
    status ENUM('QUEUED','SENT','DELIVERED','FAILED','CONFIRMED') NOT NULL DEFAULT 'QUEUED',
    retry_count INT NOT NULL DEFAULT 0,
    max_retries INT NOT NULL DEFAULT 3,
    sent_at DATETIME NULL,
    delivered_at DATETIME NULL,
    confirmed_at DATETIME NULL,
    detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_oncall_delivery_page FOREIGN KEY (page_id)
        REFERENCES oncall_page(id) ON DELETE CASCADE,
    INDEX idx_oncall_delivery_status (status, page_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS oncall_delivery_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    delivery_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_oncall_delivery_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 19: compliance retention and report scheduling.

CREATE TABLE IF NOT EXISTS compliance_retention_policy (
    policy_code VARCHAR(40) PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    retention_days INT NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (retention_days BETWEEN 1 AND 3650)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compliance_retention_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    policy_code VARCHAR(40) NOT NULL,
    archived_count BIGINT NOT NULL DEFAULT 0,
    purged_count BIGINT NOT NULL DEFAULT 0,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    executed_by VARCHAR(100) NOT NULL,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_retention_run_policy FOREIGN KEY (policy_code)
        REFERENCES compliance_retention_policy(policy_code) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compliance_retention_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    policy_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_retention_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_scheduler (
    schedule_code VARCHAR(40) PRIMARY KEY,
    report_type VARCHAR(40) NOT NULL,
    frequency ENUM('DAILY','WEEKLY','MONTHLY') NOT NULL,
    next_run_at DATETIME NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_scheduler_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    schedule_code VARCHAR(40) NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    row_count BIGINT NOT NULL DEFAULT 0,
    error_detail VARCHAR(255) NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    CONSTRAINT fk_schedule_run FOREIGN KEY (schedule_code)
        REFERENCES report_scheduler(schedule_code) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_scheduler_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    schedule_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_schedule_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 20: settlement reconciliation and statement delivery.

CREATE TABLE IF NOT EXISTS settlement_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    batch_code VARCHAR(40) NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    matched_count BIGINT NOT NULL DEFAULT 0,
    break_count BIGINT NOT NULL DEFAULT 0,
    started_by VARCHAR(100) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS settlement_item (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    run_id BIGINT NOT NULL,
    txn_ref VARCHAR(64) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('MATCHED','BREAK','RESOLVED') NOT NULL DEFAULT 'BREAK',
    detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_settlement_item_run FOREIGN KEY (run_id)
        REFERENCES settlement_run(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS settlement_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_settlement_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_delivery (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    statement_ref VARCHAR(64) NOT NULL,
    recipient VARCHAR(100) NOT NULL,
    channel ENUM('EMAIL','PORTAL') NOT NULL DEFAULT 'EMAIL',
    status ENUM('QUEUED','SENT','DELIVERED','FAILED') NOT NULL DEFAULT 'QUEUED',
    retry_count INT NOT NULL DEFAULT 0,
    max_retries INT NOT NULL DEFAULT 3,
    sent_at DATETIME NULL,
    delivered_at DATETIME NULL,
    detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS statement_delivery_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    delivery_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_statement_delivery_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 21: audit snapshots and report archives.

CREATE TABLE IF NOT EXISTS audit_snapshot (
    snapshot_code VARCHAR(40) PRIMARY KEY,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    total_events BIGINT NOT NULL DEFAULT 0,
    success_count BIGINT NOT NULL DEFAULT 0,
    failed_count BIGINT NOT NULL DEFAULT 0,
    checksum CHAR(64) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (period_end >= period_start)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_snapshot_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    snapshot_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_snapshot_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_archive (
    archive_code VARCHAR(40) PRIMARY KEY,
    report_type VARCHAR(40) NOT NULL,
    period VARCHAR(40) NOT NULL,
    row_count BIGINT NOT NULL DEFAULT 0,
    checksum CHAR(64) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_archive_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    archive_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_report_archive_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 22: KYC reviews and regulatory reports.

CREATE TABLE IF NOT EXISTS kyc_review (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    review_type ENUM('ONBOARDING','PERIODIC','ENHANCED') NOT NULL,
    status ENUM('PENDING','APPROVED','REJECTED','ESCALATED') NOT NULL DEFAULT 'PENDING',
    risk_level ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    due_date DATE NULL,
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(100) NULL,
    decided_at DATETIME NULL,
    INDEX idx_kyc_review_status (status, due_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS kyc_review_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    review_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_kyc_review_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS regulatory_report (
    report_code VARCHAR(40) PRIMARY KEY,
    regulator ENUM('OJK','BI','PPATK') NOT NULL,
    report_type VARCHAR(40) NOT NULL,
    period VARCHAR(40) NOT NULL,
    status ENUM('DRAFT','SUBMITTED','ACCEPTED','REJECTED') NOT NULL DEFAULT 'DRAFT',
    row_count BIGINT NOT NULL DEFAULT 0,
    checksum CHAR(64) NULL,
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    submitted_at DATETIME NULL,
    decided_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS regulatory_report_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    report_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_regulatory_report_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 23: loan lifecycle and term deposits.

CREATE TABLE IF NOT EXISTS loan_application (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    principal DECIMAL(18,4) NOT NULL,
    currency CHAR(3) NOT NULL,
    term_months INT NOT NULL,
    interest_rate DECIMAL(9,4) NOT NULL DEFAULT 0,
    status ENUM('PENDING','APPROVED','REJECTED','DISBURSED','CLOSED') NOT NULL DEFAULT 'PENDING',
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(100) NULL,
    decided_at DATETIME NULL,
    disbursed_at DATETIME NULL,
    CHECK (term_months BETWEEN 1 AND 360)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loan_repayment (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    loan_id BIGINT NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','PAID') NOT NULL DEFAULT 'PENDING',
    due_date DATE NULL,
    paid_at DATETIME NULL,
    CONSTRAINT fk_loan_repayment_loan FOREIGN KEY (loan_id)
        REFERENCES loan_application(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loan_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    loan_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_loan_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS deposit_account (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    principal DECIMAL(18,4) NOT NULL,
    currency CHAR(3) NOT NULL,
    term_months INT NOT NULL,
    interest_rate DECIMAL(9,4) NOT NULL DEFAULT 0,
    status ENUM('PENDING','ACTIVE','MATURED','CLOSED') NOT NULL DEFAULT 'ACTIVE',
    maturity_date DATE NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (term_months BETWEEN 1 AND 360)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS deposit_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    deposit_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_deposit_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 24: FX deals and treasury positions.

CREATE TABLE IF NOT EXISTS fx_deal (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    deal_ref VARCHAR(64) NOT NULL,
    currency_pair VARCHAR(20) NOT NULL,
    side ENUM('BUY','SELL') NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    rate DECIMAL(18,8) NOT NULL,
    value_date DATE NULL,
    status ENUM('PENDING','CONFIRMED','SETTLED','CANCELLED') NOT NULL DEFAULT 'PENDING',
    counterparty VARCHAR(100) NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fx_deal_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    deal_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_fx_deal_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS treasury_position (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    currency CHAR(3) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    as_of_date DATE NOT NULL,
    status ENUM('OPEN','CLOSED') NOT NULL DEFAULT 'OPEN',
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS treasury_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    position_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_treasury_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 25: card management and tax reporting.

CREATE TABLE IF NOT EXISTS card_account (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    card_ref VARCHAR(64) NOT NULL,
    customer_email VARCHAR(100) NOT NULL,
    card_type ENUM('DEBIT','CREDIT','PREPAID') NOT NULL,
    status ENUM('ACTIVE','BLOCKED','CLOSED') NOT NULL DEFAULT 'ACTIVE',
    limit_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS card_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    card_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_card_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tax_report (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    report_ref VARCHAR(64) NOT NULL,
    tax_type ENUM('VAT','INCOME','WITHHOLDING') NOT NULL,
    period VARCHAR(40) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    currency CHAR(3) NOT NULL,
    status ENUM('DRAFT','FILED','PAID','CLOSED') NOT NULL DEFAULT 'DRAFT',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tax_report_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    report_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_tax_report_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 26: policy attestations and regulatory calendar.

CREATE TABLE IF NOT EXISTS policy_attestation (
    attestation_code VARCHAR(40) PRIMARY KEY,
    policy_name VARCHAR(120) NOT NULL,
    owner_email VARCHAR(100) NOT NULL,
    status ENUM('PENDING','ATTESTED','EXPIRED') NOT NULL DEFAULT 'PENDING',
    due_date DATE NULL,
    attested_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS policy_attestation_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    attestation_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_policy_attestation_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS regulatory_calendar (
    event_code VARCHAR(40) PRIMARY KEY,
    title VARCHAR(120) NOT NULL,
    regulator VARCHAR(20) NOT NULL,
    due_date DATE NOT NULL,
    status ENUM('OPEN','DONE','CANCELLED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS regulatory_calendar_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    event_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_regulatory_calendar_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 27: budget and procurement.

CREATE TABLE IF NOT EXISTS budget_line (
    budget_code VARCHAR(40) PRIMARY KEY,
    cost_center VARCHAR(40) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    spent DECIMAL(18,4) NOT NULL DEFAULT 0,
    period VARCHAR(20) NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS budget_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    budget_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS procurement_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    request_code VARCHAR(40) NOT NULL,
    item VARCHAR(120) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('DRAFT','SUBMITTED','APPROVED','REJECTED','ORDERED') NOT NULL DEFAULT 'DRAFT',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS procurement_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    request_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 28: vendor and asset registers.

CREATE TABLE IF NOT EXISTS vendor (
    vendor_code VARCHAR(40) PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    status ENUM('ACTIVE','INACTIVE') NOT NULL DEFAULT 'ACTIVE',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vendor_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    vendor_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS asset_register (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    asset_code VARCHAR(40) NOT NULL,
    name VARCHAR(120) NOT NULL,
    status ENUM('ACTIVE','RETIRED') NOT NULL DEFAULT 'ACTIVE',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS asset_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    asset_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 29: vendor risk and asset maintenance.

CREATE TABLE IF NOT EXISTS vendor_risk (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    vendor_code VARCHAR(40) NOT NULL,
    risk_level ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    score INT NOT NULL DEFAULT 0,
    assessed_by VARCHAR(100) NOT NULL,
    assessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_vendor_risk_vendor (vendor_code, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vendor_risk_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    vendor_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS asset_maintenance (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    asset_code VARCHAR(40) NOT NULL,
    maintenance_type VARCHAR(40) NOT NULL,
    cost DECIMAL(18,4) NOT NULL DEFAULT 0,
    performed_by VARCHAR(100) NOT NULL,
    performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_asset_maintenance_asset (asset_code, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS asset_maintenance_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    asset_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 30: KYC reviews and risk screening.

CREATE TABLE IF NOT EXISTS kyc_case (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    review_type ENUM('ONBOARDING','PERIODIC','ENHANCED') NOT NULL,
    status ENUM('PENDING','APPROVED','REJECTED','ESCALATED') NOT NULL DEFAULT 'PENDING',
    risk_level ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    due_date DATE NULL,
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(100) NULL,
    decided_at DATETIME NULL,
    INDEX idx_kyc_case_status (status, due_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS kyc_evidence (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NOT NULL,
    evidence_type VARCHAR(40) NOT NULL,
    ref VARCHAR(128) NOT NULL,
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_kyc_evidence_case FOREIGN KEY (case_id)
        REFERENCES kyc_case(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS risk_profile (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    risk_level ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    score INT NOT NULL DEFAULT 0,
    updated_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_risk_profile_customer (customer_email)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS screening_hit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    hit_type VARCHAR(40) NOT NULL,
    severity ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    status ENUM('OPEN','CLEARED','BLOCKED') NOT NULL DEFAULT 'OPEN',
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS kyc_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    case_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_kyc_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS risk_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    customer_email VARCHAR(100) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_risk_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 30: KYC reviews and risk screening.

CREATE TABLE IF NOT EXISTS kyc_case (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    review_type ENUM('ONBOARDING','PERIODIC','ENHANCED') NOT NULL,
    status ENUM('PENDING','APPROVED','REJECTED','ESCALATED') NOT NULL DEFAULT 'PENDING',
    risk_level ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    due_date DATE NULL,
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(100) NULL,
    decided_at DATETIME NULL,
    INDEX idx_kyc_case_status (status, due_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS kyc_evidence (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NOT NULL,
    evidence_type VARCHAR(40) NOT NULL,
    ref VARCHAR(128) NOT NULL,
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_kyc_evidence_case FOREIGN KEY (case_id)
        REFERENCES kyc_case(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS risk_profile (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    risk_level ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    score INT NOT NULL DEFAULT 0,
    updated_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_risk_profile_customer (customer_email)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS screening_hit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    hit_type VARCHAR(40) NOT NULL,
    severity ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    status ENUM('OPEN','CLEARED','BLOCKED') NOT NULL DEFAULT 'OPEN',
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS kyc_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    case_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_kyc_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS risk_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    customer_email VARCHAR(100) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_risk_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sanctions_hold (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    reason VARCHAR(120) NOT NULL,
    status ENUM('ACTIVE','RELEASED') NOT NULL DEFAULT 'ACTIVE',
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    released_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sanctions_hold_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    hold_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_sanctions_hold_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 31: fraud review queue and LBPUE reporting.

CREATE TABLE IF NOT EXISTS fraud_review (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_ref VARCHAR(64) NOT NULL,
    customer_email VARCHAR(100) NOT NULL,
    status ENUM('OPEN','REVIEWING','CLEARED','BLOCKED') NOT NULL DEFAULT 'OPEN',
    risk_score INT NOT NULL DEFAULT 0,
    detail VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(100) NULL,
    decided_at DATETIME NULL,
    INDEX idx_fraud_review_status (status, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fraud_review_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    review_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_fraud_review_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS lbpue_report (
    report_code VARCHAR(40) PRIMARY KEY,
    period VARCHAR(20) NOT NULL,
    status ENUM('DRAFT','GENERATED','SUBMITTED') NOT NULL DEFAULT 'DRAFT',
    row_count BIGINT NOT NULL DEFAULT 0,
    checksum CHAR(64) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    submitted_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS lbpue_report_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    report_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_lbpue_report_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 32: GL revaluation and period close.

CREATE TABLE IF NOT EXISTS gl_revaluation_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    period VARCHAR(20) NOT NULL,
    currency CHAR(3) NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    matched_count BIGINT NOT NULL DEFAULT 0,
    diff_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS gl_revaluation_line (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    run_id BIGINT NOT NULL,
    account_code VARCHAR(20) NOT NULL,
    original_balance DECIMAL(18,4) NOT NULL DEFAULT 0,
    revalued_balance DECIMAL(18,4) NOT NULL DEFAULT 0,
    diff DECIMAL(18,4) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_gl_reval_line_run FOREIGN KEY (run_id)
        REFERENCES gl_revaluation_run(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS gl_revaluation_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gl_reval_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS gl_period_lock (
    period VARCHAR(20) PRIMARY KEY,
    status ENUM('OPEN','LOCKED','CLOSED') NOT NULL DEFAULT 'OPEN',
    locked_by VARCHAR(100) NULL,
    locked_at DATETIME NULL,
    closed_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS gl_period_lock_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    period VARCHAR(20) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gl_period_lock_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 1 Sprint 1 slice 33: fee waiver and limit profiles.

CREATE TABLE IF NOT EXISTS fee_waiver_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    fee_type VARCHAR(40) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
    reason VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(100) NULL,
    decided_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fee_waiver_request_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    waiver_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS limit_profile (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_email VARCHAR(100) NOT NULL,
    daily_limit DECIMAL(18,4) NOT NULL,
    monthly_limit DECIMAL(18,4) NOT NULL,
    velocity_tier VARCHAR(20) NOT NULL DEFAULT 'STANDARD',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_limit_profile_customer (customer_email)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS limit_profile_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    profile_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Phase 3 slice: security, data governance, and certification.

CREATE TABLE IF NOT EXISTS legal_hold (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    subject_email VARCHAR(100) NOT NULL,
    case_ref VARCHAR(64) NOT NULL,
    scope ENUM('USER','ACCOUNT','AUDIT','LEDGER','GENERAL') NOT NULL DEFAULT 'GENERAL',
    status ENUM('ACTIVE','RELEASED') NOT NULL DEFAULT 'ACTIVE',
    reason VARCHAR(255) NULL,
    placed_by VARCHAR(100) NOT NULL,
    placed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    released_by VARCHAR(100) NULL,
    released_at DATETIME NULL,
    UNIQUE KEY uq_legal_hold_case (case_ref),
    INDEX idx_legal_hold_subject (subject_email, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS legal_hold_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    hold_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_legal_hold_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS key_rotation_plan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(64) NOT NULL,
    current_version INT NOT NULL DEFAULT 1,
    status ENUM('SCHEDULED','ACTIVE','COMPLETED','CANCELLED') NOT NULL DEFAULT 'SCHEDULED',
    overlap_seconds INT NOT NULL DEFAULT 300,
    next_rotation_at DATETIME NOT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    UNIQUE KEY uq_key_rotation_key (key_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS key_rotation_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    plan_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_key_rotation_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dsar_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    subject_email VARCHAR(100) NOT NULL,
    request_type ENUM('EXPORT','ERASE') NOT NULL DEFAULT 'EXPORT',
    status ENUM('RECEIVED','IN_PROGRESS','FULFILLED','REJECTED') NOT NULL DEFAULT 'RECEIVED',
    scope VARCHAR(64) NOT NULL DEFAULT 'PROFILE',
    detail VARCHAR(255) NULL,
    received_by VARCHAR(100) NOT NULL,
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(100) NULL,
    decided_at DATETIME NULL,
    INDEX idx_dsar_subject (subject_email, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dsar_request_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    request_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_dsar_request_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS retention_job_policy (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    data_class VARCHAR(40) NOT NULL,
    retention_days INT NOT NULL,
    enabled TINYINT NOT NULL DEFAULT 1,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_retention_job_class (data_class)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS retention_job_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    data_class VARCHAR(40) NOT NULL,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'RUNNING',
    cutoff_at DATETIME NOT NULL,
    archived_count BIGINT NOT NULL DEFAULT 0,
    deleted_count BIGINT NOT NULL DEFAULT 0,
    skipped_count BIGINT NOT NULL DEFAULT 0,
    detail VARCHAR(255) NULL,
    executed_by VARCHAR(100) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS retention_job_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_retention_job_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- 12b. Migration baseline: fresh installs start here. Every migration
-- whose effects are already folded into this file is recorded below, so
-- database/migrate.sh only applies newer ones. When adding a migration, fold
-- its objects into this file AND extend this list (enforced by
-- tests/test_migrate.sh: the listed versions must equal the migration files).
INSERT IGNORE INTO schema_migrations (version) VALUES
('0001_pending_transactions_cascade'),
('0002_refresh_sessions'),
('0003_email_fk_update_cascade'),
('0004_pending_fk_update_cascade'),
('0005_refresh_session_family'),
('0006_user_token_version'),
('0007_drop_unused_schema'),
('0008_exchange_rates'),
('0009_revoked_access_tokens'),
('0010_audit_trail_archive'),
('0011_password_reset_purpose'),
('0012_verification_attempts'),
('0013_login_lockout_columns'),
('0014_mfa_totp'),
('0015_pending_key_scoped'),
('0016_transfer_reversals'),
('0017_ledger_exchange_rate'),
('0018_audit_detail'),
('0019_pending_id'),
('0020_pending_archive'),
('0021_user_status_lifecycle'),
('0022_refresh_family_limits'),
('0023_session_metadata'),
('0024_audit_actor'),
('0025_audit_integrity'),
('0026_ledger_sender'),
('0027_ledger_integrity'),
('0028_audit_append_only'),
('0029_fx_lookup_index'),
('0030_journal_entries'),
('0031_holds_fees'),
('0032_reconciliation_runs'),
('0033_dual_control'),
('0034_notification_outbox'),
('0035_mfa_recovery'),
('0036_disputes'),
('0037_ledger_rate_precision'),
('0038_reversal_fee_policy'),
('0039_fx_pnl_account'),
('0040_control_account_uniqueness'),
('0041_access_review'),
('0042_scoped_permissions'),
('0043_session_security'),
('0044_password_policy'),
('0045_customer_step_up'),
('0046_dormant_lifecycle'),
('0047_ref_entities'),
('0048_ref_entities_batch2'),
('0049_ref_entities_batch3'),
('0050_ref_entities_batch4'),
('0051_ref_entities_batch4_tail'),
('0052_ref_entities_batch5'),
('0053_reference_engine'),
('0054_reference_cutover_country_holiday'),
('0055_reference_cutover_fee_limit_product'),
('0056_gl_core'),
('0057_gl_period'),
('0058_batch_core'),
('0059_report_import'),
('0060_eod_fee'),
('0061_statement_eod_jobs'),
('0062_notification_center'),
('0063_pay_recon'),
('0064_post_delivery'),
('0065_dispute_export'),
('0066_recon_alerts'),
('0067_stmt_recon'),
('0068_standing_oncall'),
('0069_audit_importrecon'),
('0070_recon_dispute_notify'),
('0071_export_escalation'),
('0072_audit_compliance'),
('0073_hold_delivery'),
('0074_retention_scheduler'),
('0075_settlement_statement_delivery'),
('0076_audit_snapshot_report_archive'),
('0077_kyc_regulatory'),
('0078_loan_deposit'),
('0079_fx_treasury'),
('0080_card_tax'),
('0081_policy_calendar'),
('0082_budget_procurement'),
('0083_vendor_asset'),
('0084_vendor_asset_ops'),
('0085_kyc_risk'),
('0086_fraud_lbpue'),
('0087_gl_reval_close'),
('0088_fee_waiver_limits'),
('0089_security_data_cert');


-- Indexes
CREATE INDEX idx_user_email ON users(email);
CREATE INDEX idx_users_dormant ON users(status, last_login_at);
CREATE INDEX idx_currency_iso ON currencies(iso_code);
CREATE INDEX idx_exchange_lookup ON exchange_rates(base_currency_id, target_currency_id);
CREATE INDEX idx_acc_user ON accounts(user_id);
CREATE INDEX idx_acc_balance ON accounts(balance);
CREATE INDEX idx_ledger_txn ON ledger(txn_ref);
CREATE INDEX idx_ledger_acc_date ON ledger(account_id, created_at);
CREATE INDEX idx_audit_user_date ON audit_trail(user_id, created_at);
CREATE INDEX idx_audit_entity ON audit_trail(entity_type, entity_id);

-- Preserve live audit rows in the immutable archive before a user delete
-- cascades them away, so deleting a user cannot destroy audit evidence.
DELIMITER //
CREATE TRIGGER IF NOT EXISTS trg_recon_run_no_update BEFORE UPDATE ON reconciliation_runs
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'reconciliation runs are immutable';
END//

DELIMITER //
CREATE TRIGGER IF NOT EXISTS trg_audit_snapshot_user_delete BEFORE DELETE ON users
FOR EACH ROW
BEGIN
    INSERT IGNORE INTO audit_trail_archive (audit_id, user_id, actor_id, action, entity_type, entity_id, detail, status, journal_id, created_at)
    SELECT audit_id, user_id, actor_id, action, entity_type, entity_id, detail, status, journal_id, created_at
    FROM audit_trail WHERE user_id = OLD.id;
END//
DELIMITER ;

-- The audit trail is append-only: a correction is a new entry, never an
-- in-place edit. (DELETE stays allowed so the user-delete cascade can move
-- rows into audit_trail_archive via the snapshot trigger above.)
DELIMITER //
CREATE TRIGGER IF NOT EXISTS trg_audit_no_update BEFORE UPDATE ON audit_trail
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_trail is append-only (no UPDATE)';
END//
DELIMITER ;

-- Ledger durability + immutability: append-only (no UPDATE), and preserve rows
-- in the immutable archive before an account delete cascades them away.
DELIMITER //
CREATE TRIGGER IF NOT EXISTS trg_ledger_no_update BEFORE UPDATE ON ledger
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ledger is append-only (no UPDATE)';
END//

CREATE TRIGGER IF NOT EXISTS trg_ledger_archive_account BEFORE DELETE ON accounts
FOR EACH ROW
BEGIN
    INSERT IGNORE INTO ledger_archive (ledger_id, txn_ref, account_id, amount, type, currency_id, from_email, description, exchange_rate, journal_id, created_at)
    SELECT ledger_id, txn_ref, account_id, amount, type, currency_id, from_email, description, exchange_rate, journal_id, created_at
    FROM ledger WHERE account_id = OLD.account_id;
END//
DELIMITER ;

CREATE TABLE IF NOT EXISTS recon_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    finding_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_recon_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
