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
    CONSTRAINT fk_ledger_journal FOREIGN KEY (journal_id) REFERENCES journal_entries(journal_id)
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
('0050_ref_entities_batch4');


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
