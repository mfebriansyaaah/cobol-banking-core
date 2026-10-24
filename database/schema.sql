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

CREATE TABLE IF NOT EXISTS report_execution_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    template_code VARCHAR(40) NULL,
    run_id INT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_report_execution_audit_actor (actor_email, created_at),
    INDEX idx_report_execution_audit_run (run_id)
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
    job_code ENUM('HOLD_EXPIRY','DORMANT_MARK','DORMANT_SUSPEND','RECON','STATEMENT','PENDING_PURGE') NOT NULL,
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

CREATE TABLE IF NOT EXISTS regulatory_report_execution_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    report_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_regulatory_report_execution_audit_actor (actor_email, created_at)
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

CREATE TABLE IF NOT EXISTS tax_report_execution_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    report_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_tax_report_execution_audit_actor (actor_email, created_at)
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

CREATE TABLE IF NOT EXISTS lbpue_report_execution_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    report_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_lbpue_report_execution_audit_actor (actor_email, created_at)
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

-- Phase 2 slice: observability.

CREATE TABLE IF NOT EXISTS slo_definition (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    slo_name VARCHAR(64) NOT NULL,
    target_pct DECIMAL(5,2) NOT NULL,
    window_days INT NOT NULL DEFAULT 30,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_slo_name (slo_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS slo_measurement (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    slo_name VARCHAR(64) NOT NULL,
    window_start DATETIME NULL,
    window_end DATETIME NULL,
    good_events BIGINT NOT NULL DEFAULT 0,
    total_events BIGINT NOT NULL DEFAULT 0,
    burn_rate DECIMAL(8,4) NOT NULL DEFAULT 0,
    status ENUM('OK','BREACHED') NOT NULL DEFAULT 'OK',
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    recorded_by VARCHAR(100) NOT NULL,
    INDEX idx_slo_measurement_name (slo_name, recorded_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS slo_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    slo_name VARCHAR(64) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_slo_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pipeline_alert (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pipeline_name VARCHAR(100) NOT NULL,
    severity ENUM('INFO','WARNING','CRITICAL') NOT NULL DEFAULT 'INFO',
    status ENUM('OPEN','ACKNOWLEDGED','RESOLVED') NOT NULL DEFAULT 'OPEN',
    message VARCHAR(255) NOT NULL,
    source_key VARCHAR(100) NOT NULL,
    occurrence_count BIGINT NOT NULL DEFAULT 1,
    first_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acknowledged_by VARCHAR(100) NULL,
    resolved_by VARCHAR(100) NULL,
    resolved_at DATETIME NULL,
    detail VARCHAR(255) NULL,
    UNIQUE KEY uq_pipeline_alert_source (source_key, status),
    INDEX idx_pipeline_alert_status (status, severity)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pipeline_alert_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    alert_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_pipeline_alert_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 2 slice: incident and change control.

CREATE TABLE IF NOT EXISTS incident (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    severity ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT NULL DEFAULT 'MEDIUM',
    source VARCHAR(100) NOT NULL,
    status ENUM('OPEN','ACKNOWLEDGED','RESOLVED','CLOSED') NOT NULL DEFAULT 'OPEN',
    assignee VARCHAR(100) NULL,
    resolution VARCHAR(255) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at DATETIME NULL,
    closed_at DATETIME NULL,
    INDEX idx_incident_status (status, severity)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS incident_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    incident_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_incident_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS change_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    change_type VARCHAR(40) NOT NULL,
    risk ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    status ENUM('REQUESTED','APPROVED','REJECTED','DEPLOYED','ROLLEDBACK') NOT NULL DEFAULT 'REQUESTED',
    requested_by VARCHAR(100) NOT NULL,
    approved_by VARCHAR(100) NULL,
    rejected_by VARCHAR(100) NULL,
    deployed_at DATETIME NULL,
    rolled_back_at DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_change_status (status, risk)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS change_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    change_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_change_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Gradual cutover batch: CHN, BRN, CCT, DTP, NTP, STS, RTS, ACT, TXN, CHG.
-- Migrates legacy generated reference rows into the generic ref_engine.
-- Legacy tables remain as a read-only safety copy.

-- channel (CHN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('channel', 'Channel', 'Cut over from ref_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'channel', code FROM ref_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_channel t ON t.code = v.code
WHERE v.type_code = 'channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'channel', t.code, 'CUTOVER', 'migration', 'from ref_channel'
FROM ref_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- branch (BRN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('branch', 'Branch', 'Cut over from ref_branch', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'branch', code FROM ref_branch;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_branch t ON t.code = v.code
WHERE v.type_code = 'branch'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'branch', t.code, 'CUTOVER', 'migration', 'from ref_branch'
FROM ref_branch t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'branch' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- cost_center (CCT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('cost_center', 'Cost center', 'Cut over from ref_cost_center', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'cost_center', code FROM ref_cost_center;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_cost_center t ON t.code = v.code
WHERE v.type_code = 'cost_center'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'cost_center', t.code, 'CUTOVER', 'migration', 'from ref_cost_center'
FROM ref_cost_center t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'cost_center' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_type (DTP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_type', 'Document type', 'Cut over from ref_document_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_type', code FROM ref_document_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_type t ON t.code = v.code
WHERE v.type_code = 'document_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_type', t.code, 'CUTOVER', 'migration', 'from ref_document_type'
FROM ref_document_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- notification_template (NTP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('notification_template', 'Notification template', 'Cut over from ref_notification_template', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'notification_template', code FROM ref_notification_template;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_notification_template t ON t.code = v.code
WHERE v.type_code = 'notification_template'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'notification_template', t.code, 'CUTOVER', 'migration', 'from ref_notification_template'
FROM ref_notification_template t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'notification_template' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- status_code (STS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('status_code', 'Status code', 'Cut over from ref_status_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'status_code', code FROM ref_status_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_status_code t ON t.code = v.code
WHERE v.type_code = 'status_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'status_code', t.code, 'CUTOVER', 'migration', 'from ref_status_code'
FROM ref_status_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'status_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- rate_source (RTS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('rate_source', 'Rate source', 'Cut over from ref_rate_source', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'rate_source', code FROM ref_rate_source;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_rate_source t ON t.code = v.code
WHERE v.type_code = 'rate_source'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'rate_source', t.code, 'CUTOVER', 'migration', 'from ref_rate_source'
FROM ref_rate_source t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'rate_source' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_type (ACT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_type', 'Account type', 'Cut over from ref_account_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_type', code FROM ref_account_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_type t ON t.code = v.code
WHERE v.type_code = 'account_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_type', t.code, 'CUTOVER', 'migration', 'from ref_account_type'
FROM ref_account_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- transaction_code (TXN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('transaction_code', 'Transaction code', 'Cut over from ref_transaction_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'transaction_code', code FROM ref_transaction_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_transaction_code t ON t.code = v.code
WHERE v.type_code = 'transaction_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'transaction_code', t.code, 'CUTOVER', 'migration', 'from ref_transaction_code'
FROM ref_transaction_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'transaction_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- charge_code (CHG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('charge_code', 'Charge code', 'Cut over from ref_charge_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'charge_code', code FROM ref_charge_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_charge_code t ON t.code = v.code
WHERE v.type_code = 'charge_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'charge_code', t.code, 'CUTOVER', 'migration', 'from ref_charge_code'
FROM ref_charge_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'charge_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);


-- Gradual cutover batch: LMP, STL, CLR, SUS, RND, PRC, TAX, LNG, TZ, RGN, CPR, HCD, DTM, NCH, AET, SRN, ACS, PMT, CRD, ADR, PHN, EMT, RVS, RPG, CTY, PRV, DST, PST, REG, DEP, TEM, JOB, EGR, PCT, LNT, DPT, CDP, FTP, CHT, RTT, TER, DVT, ERR, RSN, DCS, TPT, QUE, PRI, SLA, CAL, BDY, COT, STP, PCH, CNW, MCC, ACL, BLT, ETY, JSR, PSR, GLC, STF, RPT, AGP, AST, BCL, LCL, JTY, PFR, ACB, DCB, INB, CPM, RIX, RBK, SPT, FEB, FFQ, CHB, TXB, TXJ, DCT, DFM, NPR, DCH, MSG, TSC, RFQ, RCG, EXT, FFM, BGR, BST, JPR, SCH, CLT, TZR, CGP, RGP, BGP, CHC, USG, CSG, APR, AOW, ARS, AFT, PFT, PGR, PFM, PDS, PTR, PGP, FWV, FCP, FRD, CGR, TGR, TRT, LMB, LFQ, LSC, TCL, TXG, TSR, TCH, PSM, PRL, SCY, CCY, COG, VDR, PWN, RVR, AJR, DSR, CMC, SVL, ESL, CSP, CST, WFA, WFR, CUT, CUG, CUS, CUC, CUI, CUO, CUQ, CUV, IDT, IDS, AFM, ADS, CNT, CNS, CSN, CSS, DSS, DSO, DOW, VFT, VFS, RVT, RVO, APT, APO, RQT, RQS, TKS, TKP, QUS, QUT, NFT, NFR, MSS, MSC, EVT, EVS, AUR, AUS, AUV, RLY, RCL, RFL, RPM, RSD, RDV, ESD, EDV, FSR, FST, FDR.
-- Migrates legacy generated reference rows into the generic ref_engine.
-- Legacy tables remain as a read-only safety copy.

-- limit_profile (LMP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('limit_profile', 'Limit profile', 'Cut over from ref_limit_profile', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'limit_profile', code FROM ref_limit_profile;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_limit_profile t ON t.code = v.code
WHERE v.type_code = 'limit_profile'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'limit_profile', t.code, 'CUTOVER', 'migration', 'from ref_limit_profile'
FROM ref_limit_profile t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'limit_profile' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- settlement_account (STL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('settlement_account', 'Settlement account', 'Cut over from ref_settlement_account', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'settlement_account', code FROM ref_settlement_account;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_settlement_account t ON t.code = v.code
WHERE v.type_code = 'settlement_account'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'settlement_account', t.code, 'CUTOVER', 'migration', 'from ref_settlement_account'
FROM ref_settlement_account t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'settlement_account' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- clearing_account (CLR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('clearing_account', 'Clearing account', 'Cut over from ref_clearing_account', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'clearing_account', code FROM ref_clearing_account;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_clearing_account t ON t.code = v.code
WHERE v.type_code = 'clearing_account'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'clearing_account', t.code, 'CUTOVER', 'migration', 'from ref_clearing_account'
FROM ref_clearing_account t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'clearing_account' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- suspense_account (SUS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('suspense_account', 'Suspense account', 'Cut over from ref_suspense_account', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'suspense_account', code FROM ref_suspense_account;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_suspense_account t ON t.code = v.code
WHERE v.type_code = 'suspense_account'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'suspense_account', t.code, 'CUTOVER', 'migration', 'from ref_suspense_account'
FROM ref_suspense_account t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'suspense_account' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- rounding_rule (RND)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('rounding_rule', 'Rounding rule', 'Cut over from ref_rounding_rule', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'rounding_rule', code FROM ref_rounding_rule;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_rounding_rule t ON t.code = v.code
WHERE v.type_code = 'rounding_rule'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'rounding_rule', t.code, 'CUTOVER', 'migration', 'from ref_rounding_rule'
FROM ref_rounding_rule t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'rounding_rule' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- precision_rule (PRC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('precision_rule', 'Precision rule', 'Cut over from ref_precision_rule', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'precision_rule', code FROM ref_precision_rule;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_precision_rule t ON t.code = v.code
WHERE v.type_code = 'precision_rule'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'precision_rule', t.code, 'CUTOVER', 'migration', 'from ref_precision_rule'
FROM ref_precision_rule t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'precision_rule' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- tax_code (TAX)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('tax_code', 'Tax code', 'Cut over from ref_tax_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'tax_code', code FROM ref_tax_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_tax_code t ON t.code = v.code
WHERE v.type_code = 'tax_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'tax_code', t.code, 'CUTOVER', 'migration', 'from ref_tax_code'
FROM ref_tax_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'tax_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- language (LNG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('language', 'Language', 'Cut over from ref_language', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'language', code FROM ref_language;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_language t ON t.code = v.code
WHERE v.type_code = 'language'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'language', t.code, 'CUTOVER', 'migration', 'from ref_language'
FROM ref_language t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'language' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- timezone (TZ)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('timezone', 'Timezone', 'Cut over from ref_timezone', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'timezone', code FROM ref_timezone;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_timezone t ON t.code = v.code
WHERE v.type_code = 'timezone'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'timezone', t.code, 'CUTOVER', 'migration', 'from ref_timezone'
FROM ref_timezone t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'timezone' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- country_region (RGN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('country_region', 'Country region', 'Cut over from ref_country_region', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'country_region', code FROM ref_country_region;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_country_region t ON t.code = v.code
WHERE v.type_code = 'country_region'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'country_region', t.code, 'CUTOVER', 'migration', 'from ref_country_region'
FROM ref_country_region t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'country_region' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- currency_pair (CPR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('currency_pair', 'Currency pair', 'Cut over from ref_currency_pair', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'currency_pair', code FROM ref_currency_pair;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_currency_pair t ON t.code = v.code
WHERE v.type_code = 'currency_pair'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'currency_pair', t.code, 'CUTOVER', 'migration', 'from ref_currency_pair'
FROM ref_currency_pair t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'currency_pair' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- holiday_calendar (HCD)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('holiday_calendar', 'Holiday calendar', 'Cut over from ref_holiday_calendar', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'holiday_calendar', code FROM ref_holiday_calendar;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_holiday_calendar t ON t.code = v.code
WHERE v.type_code = 'holiday_calendar'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'holiday_calendar', t.code, 'CUTOVER', 'migration', 'from ref_holiday_calendar'
FROM ref_holiday_calendar t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'holiday_calendar' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_template (DTM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_template', 'Document template', 'Cut over from ref_document_template', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_template', code FROM ref_document_template;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_template t ON t.code = v.code
WHERE v.type_code = 'document_template'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_template', t.code, 'CUTOVER', 'migration', 'from ref_document_template'
FROM ref_document_template t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_template' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- notification_channel (NCH)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('notification_channel', 'Notification channel', 'Cut over from ref_notification_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'notification_channel', code FROM ref_notification_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_notification_channel t ON t.code = v.code
WHERE v.type_code = 'notification_channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'notification_channel', t.code, 'CUTOVER', 'migration', 'from ref_notification_channel'
FROM ref_notification_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'notification_channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- audit_event_type (AET)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('audit_event_type', 'Audit event type', 'Cut over from ref_audit_event_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'audit_event_type', code FROM ref_audit_event_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_audit_event_type t ON t.code = v.code
WHERE v.type_code = 'audit_event_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'audit_event_type', t.code, 'CUTOVER', 'migration', 'from ref_audit_event_type'
FROM ref_audit_event_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'audit_event_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- status_reason (SRN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('status_reason', 'Status reason', 'Cut over from ref_status_reason', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'status_reason', code FROM ref_status_reason;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_status_reason t ON t.code = v.code
WHERE v.type_code = 'status_reason'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'status_reason', t.code, 'CUTOVER', 'migration', 'from ref_status_reason'
FROM ref_status_reason t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'status_reason' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_status (ACS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_status', 'Account status', 'Cut over from ref_account_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_status', code FROM ref_account_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_status t ON t.code = v.code
WHERE v.type_code = 'account_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_status', t.code, 'CUTOVER', 'migration', 'from ref_account_status'
FROM ref_account_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- payment_type (PMT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('payment_type', 'Payment type', 'Cut over from ref_payment_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'payment_type', code FROM ref_payment_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_payment_type t ON t.code = v.code
WHERE v.type_code = 'payment_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'payment_type', t.code, 'CUTOVER', 'migration', 'from ref_payment_type'
FROM ref_payment_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'payment_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- card_type (CRD)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('card_type', 'Card type', 'Cut over from ref_card_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'card_type', code FROM ref_card_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_card_type t ON t.code = v.code
WHERE v.type_code = 'card_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'card_type', t.code, 'CUTOVER', 'migration', 'from ref_card_type'
FROM ref_card_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'card_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- address_type (ADR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('address_type', 'Address type', 'Cut over from ref_address_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'address_type', code FROM ref_address_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_address_type t ON t.code = v.code
WHERE v.type_code = 'address_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'address_type', t.code, 'CUTOVER', 'migration', 'from ref_address_type'
FROM ref_address_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'address_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- phone_type (PHN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('phone_type', 'Phone type', 'Cut over from ref_phone_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'phone_type', code FROM ref_phone_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_phone_type t ON t.code = v.code
WHERE v.type_code = 'phone_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'phone_type', t.code, 'CUTOVER', 'migration', 'from ref_phone_type'
FROM ref_phone_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'phone_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- email_type (EMT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('email_type', 'Email type', 'Cut over from ref_email_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'email_type', code FROM ref_email_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_email_type t ON t.code = v.code
WHERE v.type_code = 'email_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'email_type', t.code, 'CUTOVER', 'migration', 'from ref_email_type'
FROM ref_email_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'email_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- review_state (RVS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('review_state', 'Review state', 'Cut over from ref_review_state', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'review_state', code FROM ref_review_state;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_review_state t ON t.code = v.code
WHERE v.type_code = 'review_state'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'review_state', t.code, 'CUTOVER', 'migration', 'from ref_review_state'
FROM ref_review_state t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'review_state' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_group (RPG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_group', 'Report group', 'Cut over from ref_report_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_group', code FROM ref_report_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_group t ON t.code = v.code
WHERE v.type_code = 'report_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_group', t.code, 'CUTOVER', 'migration', 'from ref_report_group'
FROM ref_report_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- city (CTY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('city', 'City', 'Cut over from ref_city', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'city', code FROM ref_city;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_city t ON t.code = v.code
WHERE v.type_code = 'city'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'city', t.code, 'CUTOVER', 'migration', 'from ref_city'
FROM ref_city t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'city' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- province (PRV)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('province', 'Province', 'Cut over from ref_province', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'province', code FROM ref_province;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_province t ON t.code = v.code
WHERE v.type_code = 'province'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'province', t.code, 'CUTOVER', 'migration', 'from ref_province'
FROM ref_province t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'province' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- district (DST)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('district', 'District', 'Cut over from ref_district', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'district', code FROM ref_district;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_district t ON t.code = v.code
WHERE v.type_code = 'district'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'district', t.code, 'CUTOVER', 'migration', 'from ref_district'
FROM ref_district t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'district' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- postal_code (PST)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('postal_code', 'Postal code', 'Cut over from ref_postal_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'postal_code', code FROM ref_postal_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_postal_code t ON t.code = v.code
WHERE v.type_code = 'postal_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'postal_code', t.code, 'CUTOVER', 'migration', 'from ref_postal_code'
FROM ref_postal_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'postal_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- region (REG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('region', 'Region', 'Cut over from ref_region', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'region', code FROM ref_region;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_region t ON t.code = v.code
WHERE v.type_code = 'region'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'region', t.code, 'CUTOVER', 'migration', 'from ref_region'
FROM ref_region t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'region' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- department (DEP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('department', 'Department', 'Cut over from ref_department', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'department', code FROM ref_department;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_department t ON t.code = v.code
WHERE v.type_code = 'department'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'department', t.code, 'CUTOVER', 'migration', 'from ref_department'
FROM ref_department t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'department' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- team (TEM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('team', 'Team', 'Cut over from ref_team', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'team', code FROM ref_team;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_team t ON t.code = v.code
WHERE v.type_code = 'team'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'team', t.code, 'CUTOVER', 'migration', 'from ref_team'
FROM ref_team t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'team' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- job_title (JOB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('job_title', 'Job title', 'Cut over from ref_job_title', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'job_title', code FROM ref_job_title;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_job_title t ON t.code = v.code
WHERE v.type_code = 'job_title'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'job_title', t.code, 'CUTOVER', 'migration', 'from ref_job_title'
FROM ref_job_title t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'job_title' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- employee_grade (EGR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('employee_grade', 'Employee grade', 'Cut over from ref_employee_grade', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'employee_grade', code FROM ref_employee_grade;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_employee_grade t ON t.code = v.code
WHERE v.type_code = 'employee_grade'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'employee_grade', t.code, 'CUTOVER', 'migration', 'from ref_employee_grade'
FROM ref_employee_grade t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'employee_grade' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- profit_center (PCT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('profit_center', 'Profit center', 'Cut over from ref_profit_center', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'profit_center', code FROM ref_profit_center;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_profit_center t ON t.code = v.code
WHERE v.type_code = 'profit_center'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'profit_center', t.code, 'CUTOVER', 'migration', 'from ref_profit_center'
FROM ref_profit_center t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'profit_center' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- loan_type (LNT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('loan_type', 'Loan type', 'Cut over from ref_loan_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'loan_type', code FROM ref_loan_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_loan_type t ON t.code = v.code
WHERE v.type_code = 'loan_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'loan_type', t.code, 'CUTOVER', 'migration', 'from ref_loan_type'
FROM ref_loan_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'loan_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- deposit_type (DPT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('deposit_type', 'Deposit type', 'Cut over from ref_deposit_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'deposit_type', code FROM ref_deposit_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_deposit_type t ON t.code = v.code
WHERE v.type_code = 'deposit_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'deposit_type', t.code, 'CUTOVER', 'migration', 'from ref_deposit_type'
FROM ref_deposit_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'deposit_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- card_product (CDP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('card_product', 'Card product', 'Cut over from ref_card_product', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'card_product', code FROM ref_card_product;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_card_product t ON t.code = v.code
WHERE v.type_code = 'card_product'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'card_product', t.code, 'CUTOVER', 'migration', 'from ref_card_product'
FROM ref_card_product t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'card_product' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- fee_type (FTP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('fee_type', 'Fee type', 'Cut over from ref_fee_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_type', code FROM ref_fee_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_type t ON t.code = v.code
WHERE v.type_code = 'fee_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_type', t.code, 'CUTOVER', 'migration', 'from ref_fee_type'
FROM ref_fee_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- charge_type (CHT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('charge_type', 'Charge type', 'Cut over from ref_charge_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'charge_type', code FROM ref_charge_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_charge_type t ON t.code = v.code
WHERE v.type_code = 'charge_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'charge_type', t.code, 'CUTOVER', 'migration', 'from ref_charge_type'
FROM ref_charge_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'charge_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- rate_type (RTT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('rate_type', 'Rate type', 'Cut over from ref_rate_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'rate_type', code FROM ref_rate_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_rate_type t ON t.code = v.code
WHERE v.type_code = 'rate_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'rate_type', t.code, 'CUTOVER', 'migration', 'from ref_rate_type'
FROM ref_rate_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'rate_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- tier (TER)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('tier', 'Tier', 'Cut over from ref_tier', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'tier', code FROM ref_tier;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_tier t ON t.code = v.code
WHERE v.type_code = 'tier'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'tier', t.code, 'CUTOVER', 'migration', 'from ref_tier'
FROM ref_tier t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'tier' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- device_type (DVT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('device_type', 'Device type', 'Cut over from ref_device_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'device_type', code FROM ref_device_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_device_type t ON t.code = v.code
WHERE v.type_code = 'device_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'device_type', t.code, 'CUTOVER', 'migration', 'from ref_device_type'
FROM ref_device_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'device_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- error_code (ERR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('error_code', 'Error code', 'Cut over from ref_error_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'error_code', code FROM ref_error_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_error_code t ON t.code = v.code
WHERE v.type_code = 'error_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'error_code', t.code, 'CUTOVER', 'migration', 'from ref_error_code'
FROM ref_error_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'error_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- reason_code (RSN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('reason_code', 'Reason code', 'Cut over from ref_reason_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'reason_code', code FROM ref_reason_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_reason_code t ON t.code = v.code
WHERE v.type_code = 'reason_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'reason_code', t.code, 'CUTOVER', 'migration', 'from ref_reason_code'
FROM ref_reason_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'reason_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_status (DCS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_status', 'Document status', 'Cut over from ref_document_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_status', code FROM ref_document_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_status t ON t.code = v.code
WHERE v.type_code = 'document_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_status', t.code, 'CUTOVER', 'migration', 'from ref_document_status'
FROM ref_document_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- template_type (TPT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('template_type', 'Template type', 'Cut over from ref_template_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'template_type', code FROM ref_template_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_template_type t ON t.code = v.code
WHERE v.type_code = 'template_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'template_type', t.code, 'CUTOVER', 'migration', 'from ref_template_type'
FROM ref_template_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'template_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- queue (QUE)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('queue', 'Queue', 'Cut over from ref_queue', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'queue', code FROM ref_queue;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_queue t ON t.code = v.code
WHERE v.type_code = 'queue'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'queue', t.code, 'CUTOVER', 'migration', 'from ref_queue'
FROM ref_queue t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'queue' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- priority (PRI)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('priority', 'Priority', 'Cut over from ref_priority', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'priority', code FROM ref_priority;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_priority t ON t.code = v.code
WHERE v.type_code = 'priority'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'priority', t.code, 'CUTOVER', 'migration', 'from ref_priority'
FROM ref_priority t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'priority' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- sla_profile (SLA)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('sla_profile', 'Sla profile', 'Cut over from ref_sla_profile', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'sla_profile', code FROM ref_sla_profile;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_sla_profile t ON t.code = v.code
WHERE v.type_code = 'sla_profile'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'sla_profile', t.code, 'CUTOVER', 'migration', 'from ref_sla_profile'
FROM ref_sla_profile t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'sla_profile' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- calendar (CAL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('calendar', 'Calendar', 'Cut over from ref_calendar', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'calendar', code FROM ref_calendar;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_calendar t ON t.code = v.code
WHERE v.type_code = 'calendar'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'calendar', t.code, 'CUTOVER', 'migration', 'from ref_calendar'
FROM ref_calendar t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'calendar' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- business_day (BDY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('business_day', 'Business day', 'Cut over from ref_business_day', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'business_day', code FROM ref_business_day;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_business_day t ON t.code = v.code
WHERE v.type_code = 'business_day'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'business_day', t.code, 'CUTOVER', 'migration', 'from ref_business_day'
FROM ref_business_day t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'business_day' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- cut_off_time (COT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('cut_off_time', 'Cut off time', 'Cut over from ref_cut_off_time', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'cut_off_time', code FROM ref_cut_off_time;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_cut_off_time t ON t.code = v.code
WHERE v.type_code = 'cut_off_time'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'cut_off_time', t.code, 'CUTOVER', 'migration', 'from ref_cut_off_time'
FROM ref_cut_off_time t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'cut_off_time' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- settlement_type (STP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('settlement_type', 'Settlement type', 'Cut over from ref_settlement_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'settlement_type', code FROM ref_settlement_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_settlement_type t ON t.code = v.code
WHERE v.type_code = 'settlement_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'settlement_type', t.code, 'CUTOVER', 'migration', 'from ref_settlement_type'
FROM ref_settlement_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'settlement_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- payment_channel (PCH)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('payment_channel', 'Payment channel', 'Cut over from ref_payment_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'payment_channel', code FROM ref_payment_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_payment_channel t ON t.code = v.code
WHERE v.type_code = 'payment_channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'payment_channel', t.code, 'CUTOVER', 'migration', 'from ref_payment_channel'
FROM ref_payment_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'payment_channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- card_network (CNW)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('card_network', 'Card network', 'Cut over from ref_card_network', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'card_network', code FROM ref_card_network;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_card_network t ON t.code = v.code
WHERE v.type_code = 'card_network'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'card_network', t.code, 'CUTOVER', 'migration', 'from ref_card_network'
FROM ref_card_network t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'card_network' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- merchant_category (MCC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('merchant_category', 'Merchant category', 'Cut over from ref_merchant_category', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'merchant_category', code FROM ref_merchant_category;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_merchant_category t ON t.code = v.code
WHERE v.type_code = 'merchant_category'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'merchant_category', t.code, 'CUTOVER', 'migration', 'from ref_merchant_category'
FROM ref_merchant_category t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'merchant_category' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_class (ACL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_class', 'Account class', 'Cut over from ref_account_class', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_class', code FROM ref_account_class;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_class t ON t.code = v.code
WHERE v.type_code = 'account_class'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_class', t.code, 'CUTOVER', 'migration', 'from ref_account_class'
FROM ref_account_class t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_class' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- balance_type (BLT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('balance_type', 'Balance type', 'Cut over from ref_balance_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'balance_type', code FROM ref_balance_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_balance_type t ON t.code = v.code
WHERE v.type_code = 'balance_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'balance_type', t.code, 'CUTOVER', 'migration', 'from ref_balance_type'
FROM ref_balance_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'balance_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- entry_type (ETY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('entry_type', 'Entry type', 'Cut over from ref_entry_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'entry_type', code FROM ref_entry_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_entry_type t ON t.code = v.code
WHERE v.type_code = 'entry_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'entry_type', t.code, 'CUTOVER', 'migration', 'from ref_entry_type'
FROM ref_entry_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'entry_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- journal_source (JSR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('journal_source', 'Journal source', 'Cut over from ref_journal_source', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'journal_source', code FROM ref_journal_source;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_journal_source t ON t.code = v.code
WHERE v.type_code = 'journal_source'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'journal_source', t.code, 'CUTOVER', 'migration', 'from ref_journal_source'
FROM ref_journal_source t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'journal_source' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- posting_rule (PSR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('posting_rule', 'Posting rule', 'Cut over from ref_posting_rule', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'posting_rule', code FROM ref_posting_rule;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_posting_rule t ON t.code = v.code
WHERE v.type_code = 'posting_rule'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'posting_rule', t.code, 'CUTOVER', 'migration', 'from ref_posting_rule'
FROM ref_posting_rule t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'posting_rule' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- gl_category (GLC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('gl_category', 'Gl category', 'Cut over from ref_gl_category', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'gl_category', code FROM ref_gl_category;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_gl_category t ON t.code = v.code
WHERE v.type_code = 'gl_category'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'gl_category', t.code, 'CUTOVER', 'migration', 'from ref_gl_category'
FROM ref_gl_category t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'gl_category' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- statement_format (STF)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('statement_format', 'Statement format', 'Cut over from ref_statement_format', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'statement_format', code FROM ref_statement_format;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_statement_format t ON t.code = v.code
WHERE v.type_code = 'statement_format'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'statement_format', t.code, 'CUTOVER', 'migration', 'from ref_statement_format'
FROM ref_statement_format t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'statement_format' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_type (RPT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_type', 'Report type', 'Cut over from ref_report_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_type', code FROM ref_report_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_type t ON t.code = v.code
WHERE v.type_code = 'report_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_type', t.code, 'CUTOVER', 'migration', 'from ref_report_type'
FROM ref_report_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_group (AGP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_group', 'Account group', 'Cut over from ref_account_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_group', code FROM ref_account_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_group t ON t.code = v.code
WHERE v.type_code = 'account_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_group', t.code, 'CUTOVER', 'migration', 'from ref_account_group'
FROM ref_account_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_subtype (AST)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_subtype', 'Account subtype', 'Cut over from ref_account_subtype', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_subtype', code FROM ref_account_subtype;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_subtype t ON t.code = v.code
WHERE v.type_code = 'account_subtype'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_subtype', t.code, 'CUTOVER', 'migration', 'from ref_account_subtype'
FROM ref_account_subtype t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_subtype' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- balance_class (BCL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('balance_class', 'Balance class', 'Cut over from ref_balance_class', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'balance_class', code FROM ref_balance_class;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_balance_class t ON t.code = v.code
WHERE v.type_code = 'balance_class'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'balance_class', t.code, 'CUTOVER', 'migration', 'from ref_balance_class'
FROM ref_balance_class t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'balance_class' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- ledger_class (LCL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('ledger_class', 'Ledger class', 'Cut over from ref_ledger_class', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'ledger_class', code FROM ref_ledger_class;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_ledger_class t ON t.code = v.code
WHERE v.type_code = 'ledger_class'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'ledger_class', t.code, 'CUTOVER', 'migration', 'from ref_ledger_class'
FROM ref_ledger_class t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'ledger_class' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- journal_type (JTY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('journal_type', 'Journal type', 'Cut over from ref_journal_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'journal_type', code FROM ref_journal_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_journal_type t ON t.code = v.code
WHERE v.type_code = 'journal_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'journal_type', t.code, 'CUTOVER', 'migration', 'from ref_journal_type'
FROM ref_journal_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'journal_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- posting_frequency (PFR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('posting_frequency', 'Posting frequency', 'Cut over from ref_posting_frequency', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'posting_frequency', code FROM ref_posting_frequency;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_posting_frequency t ON t.code = v.code
WHERE v.type_code = 'posting_frequency'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'posting_frequency', t.code, 'CUTOVER', 'migration', 'from ref_posting_frequency'
FROM ref_posting_frequency t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'posting_frequency' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- accrual_basis (ACB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('accrual_basis', 'Accrual basis', 'Cut over from ref_accrual_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'accrual_basis', code FROM ref_accrual_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_accrual_basis t ON t.code = v.code
WHERE v.type_code = 'accrual_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'accrual_basis', t.code, 'CUTOVER', 'migration', 'from ref_accrual_basis'
FROM ref_accrual_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'accrual_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- day_count_basis (DCB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('day_count_basis', 'Day count basis', 'Cut over from ref_day_count_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'day_count_basis', code FROM ref_day_count_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_day_count_basis t ON t.code = v.code
WHERE v.type_code = 'day_count_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'day_count_basis', t.code, 'CUTOVER', 'migration', 'from ref_day_count_basis'
FROM ref_day_count_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'day_count_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- interest_basis (INB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('interest_basis', 'Interest basis', 'Cut over from ref_interest_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'interest_basis', code FROM ref_interest_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_interest_basis t ON t.code = v.code
WHERE v.type_code = 'interest_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'interest_basis', t.code, 'CUTOVER', 'migration', 'from ref_interest_basis'
FROM ref_interest_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'interest_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- compounding_method (CPM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('compounding_method', 'Compounding method', 'Cut over from ref_compounding_method', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'compounding_method', code FROM ref_compounding_method;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_compounding_method t ON t.code = v.code
WHERE v.type_code = 'compounding_method'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'compounding_method', t.code, 'CUTOVER', 'migration', 'from ref_compounding_method'
FROM ref_compounding_method t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'compounding_method' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- rate_index (RIX)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('rate_index', 'Rate index', 'Cut over from ref_rate_index', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'rate_index', code FROM ref_rate_index;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_rate_index t ON t.code = v.code
WHERE v.type_code = 'rate_index'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'rate_index', t.code, 'CUTOVER', 'migration', 'from ref_rate_index'
FROM ref_rate_index t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'rate_index' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- rate_benchmark (RBK)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('rate_benchmark', 'Rate benchmark', 'Cut over from ref_rate_benchmark', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'rate_benchmark', code FROM ref_rate_benchmark;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_rate_benchmark t ON t.code = v.code
WHERE v.type_code = 'rate_benchmark'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'rate_benchmark', t.code, 'CUTOVER', 'migration', 'from ref_rate_benchmark'
FROM ref_rate_benchmark t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'rate_benchmark' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- spread_type (SPT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('spread_type', 'Spread type', 'Cut over from ref_spread_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'spread_type', code FROM ref_spread_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_spread_type t ON t.code = v.code
WHERE v.type_code = 'spread_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'spread_type', t.code, 'CUTOVER', 'migration', 'from ref_spread_type'
FROM ref_spread_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'spread_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- fee_basis (FEB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('fee_basis', 'Fee basis', 'Cut over from ref_fee_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_basis', code FROM ref_fee_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_basis t ON t.code = v.code
WHERE v.type_code = 'fee_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_basis', t.code, 'CUTOVER', 'migration', 'from ref_fee_basis'
FROM ref_fee_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- fee_frequency (FFQ)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('fee_frequency', 'Fee frequency', 'Cut over from ref_fee_frequency', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_frequency', code FROM ref_fee_frequency;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_frequency t ON t.code = v.code
WHERE v.type_code = 'fee_frequency'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_frequency', t.code, 'CUTOVER', 'migration', 'from ref_fee_frequency'
FROM ref_fee_frequency t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_frequency' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- charge_basis (CHB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('charge_basis', 'Charge basis', 'Cut over from ref_charge_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'charge_basis', code FROM ref_charge_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_charge_basis t ON t.code = v.code
WHERE v.type_code = 'charge_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'charge_basis', t.code, 'CUTOVER', 'migration', 'from ref_charge_basis'
FROM ref_charge_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'charge_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- tax_basis (TXB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('tax_basis', 'Tax basis', 'Cut over from ref_tax_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'tax_basis', code FROM ref_tax_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_tax_basis t ON t.code = v.code
WHERE v.type_code = 'tax_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'tax_basis', t.code, 'CUTOVER', 'migration', 'from ref_tax_basis'
FROM ref_tax_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'tax_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- tax_jurisdiction (TXJ)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('tax_jurisdiction', 'Tax jurisdiction', 'Cut over from ref_tax_jurisdiction', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'tax_jurisdiction', code FROM ref_tax_jurisdiction;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_tax_jurisdiction t ON t.code = v.code
WHERE v.type_code = 'tax_jurisdiction'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'tax_jurisdiction', t.code, 'CUTOVER', 'migration', 'from ref_tax_jurisdiction'
FROM ref_tax_jurisdiction t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'tax_jurisdiction' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_category (DCT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_category', 'Document category', 'Cut over from ref_document_category', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_category', code FROM ref_document_category;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_category t ON t.code = v.code
WHERE v.type_code = 'document_category'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_category', t.code, 'CUTOVER', 'migration', 'from ref_document_category'
FROM ref_document_category t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_category' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_format (DFM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_format', 'Document format', 'Cut over from ref_document_format', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_format', code FROM ref_document_format;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_format t ON t.code = v.code
WHERE v.type_code = 'document_format'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_format', t.code, 'CUTOVER', 'migration', 'from ref_document_format'
FROM ref_document_format t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_format' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- notification_priority (NPR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('notification_priority', 'Notification priority', 'Cut over from ref_notification_priority', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'notification_priority', code FROM ref_notification_priority;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_notification_priority t ON t.code = v.code
WHERE v.type_code = 'notification_priority'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'notification_priority', t.code, 'CUTOVER', 'migration', 'from ref_notification_priority'
FROM ref_notification_priority t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'notification_priority' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- delivery_channel (DCH)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('delivery_channel', 'Delivery channel', 'Cut over from ref_delivery_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'delivery_channel', code FROM ref_delivery_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_delivery_channel t ON t.code = v.code
WHERE v.type_code = 'delivery_channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'delivery_channel', t.code, 'CUTOVER', 'migration', 'from ref_delivery_channel'
FROM ref_delivery_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'delivery_channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- message_type (MSG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('message_type', 'Message type', 'Cut over from ref_message_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'message_type', code FROM ref_message_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_message_type t ON t.code = v.code
WHERE v.type_code = 'message_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'message_type', t.code, 'CUTOVER', 'migration', 'from ref_message_type'
FROM ref_message_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'message_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- template_scope (TSC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('template_scope', 'Template scope', 'Cut over from ref_template_scope', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'template_scope', code FROM ref_template_scope;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_template_scope t ON t.code = v.code
WHERE v.type_code = 'template_scope'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'template_scope', t.code, 'CUTOVER', 'migration', 'from ref_template_scope'
FROM ref_template_scope t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'template_scope' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_frequency (RFQ)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_frequency', 'Report frequency', 'Cut over from ref_report_frequency', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_frequency', code FROM ref_report_frequency;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_frequency t ON t.code = v.code
WHERE v.type_code = 'report_frequency'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_frequency', t.code, 'CUTOVER', 'migration', 'from ref_report_frequency'
FROM ref_report_frequency t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_frequency' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_category (RCG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_category', 'Report category', 'Cut over from ref_report_category', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_category', code FROM ref_report_category;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_category t ON t.code = v.code
WHERE v.type_code = 'report_category'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_category', t.code, 'CUTOVER', 'migration', 'from ref_report_category'
FROM ref_report_category t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_category' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- export_type (EXT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('export_type', 'Export type', 'Cut over from ref_export_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'export_type', code FROM ref_export_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_export_type t ON t.code = v.code
WHERE v.type_code = 'export_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'export_type', t.code, 'CUTOVER', 'migration', 'from ref_export_type'
FROM ref_export_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'export_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- file_format (FFM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('file_format', 'File format', 'Cut over from ref_file_format', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'file_format', code FROM ref_file_format;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_file_format t ON t.code = v.code
WHERE v.type_code = 'file_format'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'file_format', t.code, 'CUTOVER', 'migration', 'from ref_file_format'
FROM ref_file_format t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'file_format' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- batch_group (BGR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('batch_group', 'Batch group', 'Cut over from ref_batch_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'batch_group', code FROM ref_batch_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_batch_group t ON t.code = v.code
WHERE v.type_code = 'batch_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'batch_group', t.code, 'CUTOVER', 'migration', 'from ref_batch_group'
FROM ref_batch_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'batch_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- batch_status (BST)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('batch_status', 'Batch status', 'Cut over from ref_batch_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'batch_status', code FROM ref_batch_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_batch_status t ON t.code = v.code
WHERE v.type_code = 'batch_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'batch_status', t.code, 'CUTOVER', 'migration', 'from ref_batch_status'
FROM ref_batch_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'batch_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- job_priority (JPR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('job_priority', 'Job priority', 'Cut over from ref_job_priority', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'job_priority', code FROM ref_job_priority;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_job_priority t ON t.code = v.code
WHERE v.type_code = 'job_priority'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'job_priority', t.code, 'CUTOVER', 'migration', 'from ref_job_priority'
FROM ref_job_priority t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'job_priority' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- schedule_type (SCH)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('schedule_type', 'Schedule type', 'Cut over from ref_schedule_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'schedule_type', code FROM ref_schedule_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_schedule_type t ON t.code = v.code
WHERE v.type_code = 'schedule_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'schedule_type', t.code, 'CUTOVER', 'migration', 'from ref_schedule_type'
FROM ref_schedule_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'schedule_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- calendar_type (CLT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('calendar_type', 'Calendar type', 'Cut over from ref_calendar_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'calendar_type', code FROM ref_calendar_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_calendar_type t ON t.code = v.code
WHERE v.type_code = 'calendar_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'calendar_type', t.code, 'CUTOVER', 'migration', 'from ref_calendar_type'
FROM ref_calendar_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'calendar_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- timezone_region (TZR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('timezone_region', 'Timezone region', 'Cut over from ref_timezone_region', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'timezone_region', code FROM ref_timezone_region;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_timezone_region t ON t.code = v.code
WHERE v.type_code = 'timezone_region'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'timezone_region', t.code, 'CUTOVER', 'migration', 'from ref_timezone_region'
FROM ref_timezone_region t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'timezone_region' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- country_group (CGP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('country_group', 'Country group', 'Cut over from ref_country_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'country_group', code FROM ref_country_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_country_group t ON t.code = v.code
WHERE v.type_code = 'country_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'country_group', t.code, 'CUTOVER', 'migration', 'from ref_country_group'
FROM ref_country_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'country_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- region_group (RGP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('region_group', 'Region group', 'Cut over from ref_region_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'region_group', code FROM ref_region_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_region_group t ON t.code = v.code
WHERE v.type_code = 'region_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'region_group', t.code, 'CUTOVER', 'migration', 'from ref_region_group'
FROM ref_region_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'region_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- branch_group (BGP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('branch_group', 'Branch group', 'Cut over from ref_branch_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'branch_group', code FROM ref_branch_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_branch_group t ON t.code = v.code
WHERE v.type_code = 'branch_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'branch_group', t.code, 'CUTOVER', 'migration', 'from ref_branch_group'
FROM ref_branch_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'branch_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- channel_class (CHC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('channel_class', 'Channel class', 'Cut over from ref_channel_class', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'channel_class', code FROM ref_channel_class;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_channel_class t ON t.code = v.code
WHERE v.type_code = 'channel_class'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'channel_class', t.code, 'CUTOVER', 'migration', 'from ref_channel_class'
FROM ref_channel_class t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'channel_class' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- user_segment (USG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('user_segment', 'User segment', 'Cut over from ref_user_segment', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'user_segment', code FROM ref_user_segment;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_user_segment t ON t.code = v.code
WHERE v.type_code = 'user_segment'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'user_segment', t.code, 'CUTOVER', 'migration', 'from ref_user_segment'
FROM ref_user_segment t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'user_segment' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_segment (CSG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_segment', 'Customer segment', 'Cut over from ref_customer_segment', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_segment', code FROM ref_customer_segment;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_segment t ON t.code = v.code
WHERE v.type_code = 'customer_segment'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_segment', t.code, 'CUTOVER', 'migration', 'from ref_customer_segment'
FROM ref_customer_segment t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_segment' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_purpose (APR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_purpose', 'Account purpose', 'Cut over from ref_account_purpose', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_purpose', code FROM ref_account_purpose;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_purpose t ON t.code = v.code
WHERE v.type_code = 'account_purpose'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_purpose', t.code, 'CUTOVER', 'migration', 'from ref_account_purpose'
FROM ref_account_purpose t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_purpose' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_ownership (AOW)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_ownership', 'Account ownership', 'Cut over from ref_account_ownership', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_ownership', code FROM ref_account_ownership;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_ownership t ON t.code = v.code
WHERE v.type_code = 'account_ownership'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_ownership', t.code, 'CUTOVER', 'migration', 'from ref_account_ownership'
FROM ref_account_ownership t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_ownership' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_restriction (ARS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_restriction', 'Account restriction', 'Cut over from ref_account_restriction', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_restriction', code FROM ref_account_restriction;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_restriction t ON t.code = v.code
WHERE v.type_code = 'account_restriction'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_restriction', t.code, 'CUTOVER', 'migration', 'from ref_account_restriction'
FROM ref_account_restriction t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_restriction' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_feature (AFT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_feature', 'Account feature', 'Cut over from ref_account_feature', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_feature', code FROM ref_account_feature;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_feature t ON t.code = v.code
WHERE v.type_code = 'account_feature'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_feature', t.code, 'CUTOVER', 'migration', 'from ref_account_feature'
FROM ref_account_feature t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_feature' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- product_feature (PFT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('product_feature', 'Product feature', 'Cut over from ref_product_feature', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'product_feature', code FROM ref_product_feature;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_product_feature t ON t.code = v.code
WHERE v.type_code = 'product_feature'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'product_feature', t.code, 'CUTOVER', 'migration', 'from ref_product_feature'
FROM ref_product_feature t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'product_feature' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- product_group (PGR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('product_group', 'Product group', 'Cut over from ref_product_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'product_group', code FROM ref_product_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_product_group t ON t.code = v.code
WHERE v.type_code = 'product_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'product_group', t.code, 'CUTOVER', 'migration', 'from ref_product_group'
FROM ref_product_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'product_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- product_family (PFM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('product_family', 'Product family', 'Cut over from ref_product_family', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'product_family', code FROM ref_product_family;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_product_family t ON t.code = v.code
WHERE v.type_code = 'product_family'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'product_family', t.code, 'CUTOVER', 'migration', 'from ref_product_family'
FROM ref_product_family t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'product_family' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- product_status (PDS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('product_status', 'Product status', 'Cut over from ref_product_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'product_status', code FROM ref_product_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_product_status t ON t.code = v.code
WHERE v.type_code = 'product_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'product_status', t.code, 'CUTOVER', 'migration', 'from ref_product_status'
FROM ref_product_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'product_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- pricing_tier (PTR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('pricing_tier', 'Pricing tier', 'Cut over from ref_pricing_tier', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'pricing_tier', code FROM ref_pricing_tier;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_pricing_tier t ON t.code = v.code
WHERE v.type_code = 'pricing_tier'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'pricing_tier', t.code, 'CUTOVER', 'migration', 'from ref_pricing_tier'
FROM ref_pricing_tier t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'pricing_tier' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- pricing_group (PGP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('pricing_group', 'Pricing group', 'Cut over from ref_pricing_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'pricing_group', code FROM ref_pricing_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_pricing_group t ON t.code = v.code
WHERE v.type_code = 'pricing_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'pricing_group', t.code, 'CUTOVER', 'migration', 'from ref_pricing_group'
FROM ref_pricing_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'pricing_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- fee_waiver (FWV)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('fee_waiver', 'Fee waiver', 'Cut over from ref_fee_waiver', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_waiver', code FROM ref_fee_waiver;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_waiver t ON t.code = v.code
WHERE v.type_code = 'fee_waiver'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_waiver', t.code, 'CUTOVER', 'migration', 'from ref_fee_waiver'
FROM ref_fee_waiver t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_waiver' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- fee_cap (FCP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('fee_cap', 'Fee cap', 'Cut over from ref_fee_cap', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_cap', code FROM ref_fee_cap;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_cap t ON t.code = v.code
WHERE v.type_code = 'fee_cap'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_cap', t.code, 'CUTOVER', 'migration', 'from ref_fee_cap'
FROM ref_fee_cap t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_cap' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- fee_rounding (FRD)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('fee_rounding', 'Fee rounding', 'Cut over from ref_fee_rounding', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_rounding', code FROM ref_fee_rounding;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_rounding t ON t.code = v.code
WHERE v.type_code = 'fee_rounding'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_rounding', t.code, 'CUTOVER', 'migration', 'from ref_fee_rounding'
FROM ref_fee_rounding t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_rounding' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- charge_group (CGR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('charge_group', 'Charge group', 'Cut over from ref_charge_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'charge_group', code FROM ref_charge_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_charge_group t ON t.code = v.code
WHERE v.type_code = 'charge_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'charge_group', t.code, 'CUTOVER', 'migration', 'from ref_charge_group'
FROM ref_charge_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'charge_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- tax_group (TGR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('tax_group', 'Tax group', 'Cut over from ref_tax_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'tax_group', code FROM ref_tax_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_tax_group t ON t.code = v.code
WHERE v.type_code = 'tax_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'tax_group', t.code, 'CUTOVER', 'migration', 'from ref_tax_group'
FROM ref_tax_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'tax_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- tax_rate_type (TRT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('tax_rate_type', 'Tax rate type', 'Cut over from ref_tax_rate_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'tax_rate_type', code FROM ref_tax_rate_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_tax_rate_type t ON t.code = v.code
WHERE v.type_code = 'tax_rate_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'tax_rate_type', t.code, 'CUTOVER', 'migration', 'from ref_tax_rate_type'
FROM ref_tax_rate_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'tax_rate_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- limit_basis (LMB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('limit_basis', 'Limit basis', 'Cut over from ref_limit_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'limit_basis', code FROM ref_limit_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_limit_basis t ON t.code = v.code
WHERE v.type_code = 'limit_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'limit_basis', t.code, 'CUTOVER', 'migration', 'from ref_limit_basis'
FROM ref_limit_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'limit_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- limit_frequency (LFQ)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('limit_frequency', 'Limit frequency', 'Cut over from ref_limit_frequency', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'limit_frequency', code FROM ref_limit_frequency;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_limit_frequency t ON t.code = v.code
WHERE v.type_code = 'limit_frequency'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'limit_frequency', t.code, 'CUTOVER', 'migration', 'from ref_limit_frequency'
FROM ref_limit_frequency t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'limit_frequency' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- limit_scope (LSC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('limit_scope', 'Limit scope', 'Cut over from ref_limit_scope', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'limit_scope', code FROM ref_limit_scope;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_limit_scope t ON t.code = v.code
WHERE v.type_code = 'limit_scope'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'limit_scope', t.code, 'CUTOVER', 'migration', 'from ref_limit_scope'
FROM ref_limit_scope t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'limit_scope' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- transaction_class (TCL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('transaction_class', 'Transaction class', 'Cut over from ref_transaction_class', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'transaction_class', code FROM ref_transaction_class;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_transaction_class t ON t.code = v.code
WHERE v.type_code = 'transaction_class'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'transaction_class', t.code, 'CUTOVER', 'migration', 'from ref_transaction_class'
FROM ref_transaction_class t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'transaction_class' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- transaction_group (TXG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('transaction_group', 'Transaction group', 'Cut over from ref_transaction_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'transaction_group', code FROM ref_transaction_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_transaction_group t ON t.code = v.code
WHERE v.type_code = 'transaction_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'transaction_group', t.code, 'CUTOVER', 'migration', 'from ref_transaction_group'
FROM ref_transaction_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'transaction_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- transaction_status (TSR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('transaction_status', 'Transaction status', 'Cut over from ref_transaction_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'transaction_status', code FROM ref_transaction_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_transaction_status t ON t.code = v.code
WHERE v.type_code = 'transaction_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'transaction_status', t.code, 'CUTOVER', 'migration', 'from ref_transaction_status'
FROM ref_transaction_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'transaction_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- transaction_channel (TCH)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('transaction_channel', 'Transaction channel', 'Cut over from ref_transaction_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'transaction_channel', code FROM ref_transaction_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_transaction_channel t ON t.code = v.code
WHERE v.type_code = 'transaction_channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'transaction_channel', t.code, 'CUTOVER', 'migration', 'from ref_transaction_channel'
FROM ref_transaction_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'transaction_channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- payment_scheme (PSM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('payment_scheme', 'Payment scheme', 'Cut over from ref_payment_scheme', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'payment_scheme', code FROM ref_payment_scheme;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_payment_scheme t ON t.code = v.code
WHERE v.type_code = 'payment_scheme'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'payment_scheme', t.code, 'CUTOVER', 'migration', 'from ref_payment_scheme'
FROM ref_payment_scheme t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'payment_scheme' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- payment_rail (PRL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('payment_rail', 'Payment rail', 'Cut over from ref_payment_rail', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'payment_rail', code FROM ref_payment_rail;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_payment_rail t ON t.code = v.code
WHERE v.type_code = 'payment_rail'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'payment_rail', t.code, 'CUTOVER', 'migration', 'from ref_payment_rail'
FROM ref_payment_rail t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'payment_rail' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- settlement_cycle (SCY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('settlement_cycle', 'Settlement cycle', 'Cut over from ref_settlement_cycle', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'settlement_cycle', code FROM ref_settlement_cycle;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_settlement_cycle t ON t.code = v.code
WHERE v.type_code = 'settlement_cycle'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'settlement_cycle', t.code, 'CUTOVER', 'migration', 'from ref_settlement_cycle'
FROM ref_settlement_cycle t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'settlement_cycle' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- clearing_cycle (CCY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('clearing_cycle', 'Clearing cycle', 'Cut over from ref_clearing_cycle', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'clearing_cycle', code FROM ref_clearing_cycle;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_clearing_cycle t ON t.code = v.code
WHERE v.type_code = 'clearing_cycle'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'clearing_cycle', t.code, 'CUTOVER', 'migration', 'from ref_clearing_cycle'
FROM ref_clearing_cycle t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'clearing_cycle' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- cut_off_group (COG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('cut_off_group', 'Cut off group', 'Cut over from ref_cut_off_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'cut_off_group', code FROM ref_cut_off_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_cut_off_group t ON t.code = v.code
WHERE v.type_code = 'cut_off_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'cut_off_group', t.code, 'CUTOVER', 'migration', 'from ref_cut_off_group'
FROM ref_cut_off_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'cut_off_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- value_date_rule (VDR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('value_date_rule', 'Value date rule', 'Cut over from ref_value_date_rule', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'value_date_rule', code FROM ref_value_date_rule;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_value_date_rule t ON t.code = v.code
WHERE v.type_code = 'value_date_rule'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'value_date_rule', t.code, 'CUTOVER', 'migration', 'from ref_value_date_rule'
FROM ref_value_date_rule t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'value_date_rule' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- posting_window (PWN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('posting_window', 'Posting window', 'Cut over from ref_posting_window', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'posting_window', code FROM ref_posting_window;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_posting_window t ON t.code = v.code
WHERE v.type_code = 'posting_window'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'posting_window', t.code, 'CUTOVER', 'migration', 'from ref_posting_window'
FROM ref_posting_window t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'posting_window' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- reversal_reason (RVR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('reversal_reason', 'Reversal reason', 'Cut over from ref_reversal_reason', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'reversal_reason', code FROM ref_reversal_reason;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_reversal_reason t ON t.code = v.code
WHERE v.type_code = 'reversal_reason'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'reversal_reason', t.code, 'CUTOVER', 'migration', 'from ref_reversal_reason'
FROM ref_reversal_reason t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'reversal_reason' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- adjustment_reason (AJR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('adjustment_reason', 'Adjustment reason', 'Cut over from ref_adjustment_reason', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'adjustment_reason', code FROM ref_adjustment_reason;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_adjustment_reason t ON t.code = v.code
WHERE v.type_code = 'adjustment_reason'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'adjustment_reason', t.code, 'CUTOVER', 'migration', 'from ref_adjustment_reason'
FROM ref_adjustment_reason t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'adjustment_reason' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- dispute_reason (DSR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('dispute_reason', 'Dispute reason', 'Cut over from ref_dispute_reason', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'dispute_reason', code FROM ref_dispute_reason;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_dispute_reason t ON t.code = v.code
WHERE v.type_code = 'dispute_reason'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'dispute_reason', t.code, 'CUTOVER', 'migration', 'from ref_dispute_reason'
FROM ref_dispute_reason t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'dispute_reason' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- complaint_category (CMC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('complaint_category', 'Complaint category', 'Cut over from ref_complaint_category', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'complaint_category', code FROM ref_complaint_category;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_complaint_category t ON t.code = v.code
WHERE v.type_code = 'complaint_category'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'complaint_category', t.code, 'CUTOVER', 'migration', 'from ref_complaint_category'
FROM ref_complaint_category t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'complaint_category' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- service_level (SVL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('service_level', 'Service level', 'Cut over from ref_service_level', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'service_level', code FROM ref_service_level;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_service_level t ON t.code = v.code
WHERE v.type_code = 'service_level'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'service_level', t.code, 'CUTOVER', 'migration', 'from ref_service_level'
FROM ref_service_level t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'service_level' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- escalation_level (ESL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('escalation_level', 'Escalation level', 'Cut over from ref_escalation_level', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'escalation_level', code FROM ref_escalation_level;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_escalation_level t ON t.code = v.code
WHERE v.type_code = 'escalation_level'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'escalation_level', t.code, 'CUTOVER', 'migration', 'from ref_escalation_level'
FROM ref_escalation_level t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'escalation_level' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- case_priority (CSP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('case_priority', 'Case priority', 'Cut over from ref_case_priority', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'case_priority', code FROM ref_case_priority;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_case_priority t ON t.code = v.code
WHERE v.type_code = 'case_priority'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'case_priority', t.code, 'CUTOVER', 'migration', 'from ref_case_priority'
FROM ref_case_priority t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'case_priority' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- case_status (CST)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('case_status', 'Case status', 'Cut over from ref_case_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'case_status', code FROM ref_case_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_case_status t ON t.code = v.code
WHERE v.type_code = 'case_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'case_status', t.code, 'CUTOVER', 'migration', 'from ref_case_status'
FROM ref_case_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'case_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- workflow_action (WFA)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('workflow_action', 'Workflow action', 'Cut over from ref_workflow_action', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'workflow_action', code FROM ref_workflow_action;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_workflow_action t ON t.code = v.code
WHERE v.type_code = 'workflow_action'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'workflow_action', t.code, 'CUTOVER', 'migration', 'from ref_workflow_action'
FROM ref_workflow_action t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'workflow_action' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- workflow_role (WFR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('workflow_role', 'Workflow role', 'Cut over from ref_workflow_role', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'workflow_role', code FROM ref_workflow_role;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_workflow_role t ON t.code = v.code
WHERE v.type_code = 'workflow_role'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'workflow_role', t.code, 'CUTOVER', 'migration', 'from ref_workflow_role'
FROM ref_workflow_role t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'workflow_role' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_type (CUT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_type', 'Customer type', 'Cut over from ref_customer_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_type', code FROM ref_customer_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_type t ON t.code = v.code
WHERE v.type_code = 'customer_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_type', t.code, 'CUTOVER', 'migration', 'from ref_customer_type'
FROM ref_customer_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_group (CUG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_group', 'Customer group', 'Cut over from ref_customer_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_group', code FROM ref_customer_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_group t ON t.code = v.code
WHERE v.type_code = 'customer_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_group', t.code, 'CUTOVER', 'migration', 'from ref_customer_group'
FROM ref_customer_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_status (CUS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_status', 'Customer status', 'Cut over from ref_customer_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_status', code FROM ref_customer_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_status t ON t.code = v.code
WHERE v.type_code = 'customer_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_status', t.code, 'CUTOVER', 'migration', 'from ref_customer_status'
FROM ref_customer_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_category (CUC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_category', 'Customer category', 'Cut over from ref_customer_category', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_category', code FROM ref_customer_category;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_category t ON t.code = v.code
WHERE v.type_code = 'customer_category'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_category', t.code, 'CUTOVER', 'migration', 'from ref_customer_category'
FROM ref_customer_category t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_category' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_industry (CUI)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_industry', 'Customer industry', 'Cut over from ref_customer_industry', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_industry', code FROM ref_customer_industry;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_industry t ON t.code = v.code
WHERE v.type_code = 'customer_industry'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_industry', t.code, 'CUTOVER', 'migration', 'from ref_customer_industry'
FROM ref_customer_industry t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_industry' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_occupation (CUO)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_occupation', 'Customer occupation', 'Cut over from ref_customer_occupation', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_occupation', code FROM ref_customer_occupation;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_occupation t ON t.code = v.code
WHERE v.type_code = 'customer_occupation'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_occupation', t.code, 'CUTOVER', 'migration', 'from ref_customer_occupation'
FROM ref_customer_occupation t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_occupation' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_source (CUQ)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_source', 'Customer source', 'Cut over from ref_customer_source', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_source', code FROM ref_customer_source;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_source t ON t.code = v.code
WHERE v.type_code = 'customer_source'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_source', t.code, 'CUTOVER', 'migration', 'from ref_customer_source'
FROM ref_customer_source t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_source' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_channel (CUV)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_channel', 'Customer channel', 'Cut over from ref_customer_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_channel', code FROM ref_customer_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_channel t ON t.code = v.code
WHERE v.type_code = 'customer_channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_channel', t.code, 'CUTOVER', 'migration', 'from ref_customer_channel'
FROM ref_customer_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- identity_type (IDT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('identity_type', 'Identity type', 'Cut over from ref_identity_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'identity_type', code FROM ref_identity_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_identity_type t ON t.code = v.code
WHERE v.type_code = 'identity_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'identity_type', t.code, 'CUTOVER', 'migration', 'from ref_identity_type'
FROM ref_identity_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'identity_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- identity_status (IDS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('identity_status', 'Identity status', 'Cut over from ref_identity_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'identity_status', code FROM ref_identity_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_identity_status t ON t.code = v.code
WHERE v.type_code = 'identity_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'identity_status', t.code, 'CUTOVER', 'migration', 'from ref_identity_status'
FROM ref_identity_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'identity_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- address_format (AFM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('address_format', 'Address format', 'Cut over from ref_address_format', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'address_format', code FROM ref_address_format;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_address_format t ON t.code = v.code
WHERE v.type_code = 'address_format'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'address_format', t.code, 'CUTOVER', 'migration', 'from ref_address_format'
FROM ref_address_format t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'address_format' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- address_status (ADS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('address_status', 'Address status', 'Cut over from ref_address_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'address_status', code FROM ref_address_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_address_status t ON t.code = v.code
WHERE v.type_code = 'address_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'address_status', t.code, 'CUTOVER', 'migration', 'from ref_address_status'
FROM ref_address_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'address_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- contact_type (CNT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('contact_type', 'Contact type', 'Cut over from ref_contact_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'contact_type', code FROM ref_contact_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_contact_type t ON t.code = v.code
WHERE v.type_code = 'contact_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'contact_type', t.code, 'CUTOVER', 'migration', 'from ref_contact_type'
FROM ref_contact_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'contact_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- contact_status (CNS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('contact_status', 'Contact status', 'Cut over from ref_contact_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'contact_status', code FROM ref_contact_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_contact_status t ON t.code = v.code
WHERE v.type_code = 'contact_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'contact_status', t.code, 'CUTOVER', 'migration', 'from ref_contact_status'
FROM ref_contact_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'contact_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- consent_type (CSN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('consent_type', 'Consent type', 'Cut over from ref_consent_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'consent_type', code FROM ref_consent_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_consent_type t ON t.code = v.code
WHERE v.type_code = 'consent_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'consent_type', t.code, 'CUTOVER', 'migration', 'from ref_consent_type'
FROM ref_consent_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'consent_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- consent_status (CSS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('consent_status', 'Consent status', 'Cut over from ref_consent_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'consent_status', code FROM ref_consent_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_consent_status t ON t.code = v.code
WHERE v.type_code = 'consent_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'consent_status', t.code, 'CUTOVER', 'migration', 'from ref_consent_status'
FROM ref_consent_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'consent_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_state (DSS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_state', 'Document state', 'Cut over from ref_document_state', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_state', code FROM ref_document_state;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_state t ON t.code = v.code
WHERE v.type_code = 'document_state'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_state', t.code, 'CUTOVER', 'migration', 'from ref_document_state'
FROM ref_document_state t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_state' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_source (DSO)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_source', 'Document source', 'Cut over from ref_document_source', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_source', code FROM ref_document_source;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_source t ON t.code = v.code
WHERE v.type_code = 'document_source'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_source', t.code, 'CUTOVER', 'migration', 'from ref_document_source'
FROM ref_document_source t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_source' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_owner (DOW)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_owner', 'Document owner', 'Cut over from ref_document_owner', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_owner', code FROM ref_document_owner;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_owner t ON t.code = v.code
WHERE v.type_code = 'document_owner'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_owner', t.code, 'CUTOVER', 'migration', 'from ref_document_owner'
FROM ref_document_owner t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_owner' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- verification_type (VFT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('verification_type', 'Verification type', 'Cut over from ref_verification_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'verification_type', code FROM ref_verification_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_verification_type t ON t.code = v.code
WHERE v.type_code = 'verification_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'verification_type', t.code, 'CUTOVER', 'migration', 'from ref_verification_type'
FROM ref_verification_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'verification_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- verification_status (VFS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('verification_status', 'Verification status', 'Cut over from ref_verification_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'verification_status', code FROM ref_verification_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_verification_status t ON t.code = v.code
WHERE v.type_code = 'verification_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'verification_status', t.code, 'CUTOVER', 'migration', 'from ref_verification_status'
FROM ref_verification_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'verification_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- review_type (RVT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('review_type', 'Review type', 'Cut over from ref_review_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'review_type', code FROM ref_review_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_review_type t ON t.code = v.code
WHERE v.type_code = 'review_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'review_type', t.code, 'CUTOVER', 'migration', 'from ref_review_type'
FROM ref_review_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'review_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- review_outcome (RVO)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('review_outcome', 'Review outcome', 'Cut over from ref_review_outcome', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'review_outcome', code FROM ref_review_outcome;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_review_outcome t ON t.code = v.code
WHERE v.type_code = 'review_outcome'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'review_outcome', t.code, 'CUTOVER', 'migration', 'from ref_review_outcome'
FROM ref_review_outcome t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'review_outcome' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- approval_type (APT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('approval_type', 'Approval type', 'Cut over from ref_approval_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'approval_type', code FROM ref_approval_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_approval_type t ON t.code = v.code
WHERE v.type_code = 'approval_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'approval_type', t.code, 'CUTOVER', 'migration', 'from ref_approval_type'
FROM ref_approval_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'approval_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- approval_outcome (APO)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('approval_outcome', 'Approval outcome', 'Cut over from ref_approval_outcome', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'approval_outcome', code FROM ref_approval_outcome;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_approval_outcome t ON t.code = v.code
WHERE v.type_code = 'approval_outcome'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'approval_outcome', t.code, 'CUTOVER', 'migration', 'from ref_approval_outcome'
FROM ref_approval_outcome t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'approval_outcome' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- request_type (RQT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('request_type', 'Request type', 'Cut over from ref_request_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'request_type', code FROM ref_request_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_request_type t ON t.code = v.code
WHERE v.type_code = 'request_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'request_type', t.code, 'CUTOVER', 'migration', 'from ref_request_type'
FROM ref_request_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'request_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- request_status (RQS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('request_status', 'Request status', 'Cut over from ref_request_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'request_status', code FROM ref_request_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_request_status t ON t.code = v.code
WHERE v.type_code = 'request_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'request_status', t.code, 'CUTOVER', 'migration', 'from ref_request_status'
FROM ref_request_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'request_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- task_status (TKS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('task_status', 'Task status', 'Cut over from ref_task_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'task_status', code FROM ref_task_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_task_status t ON t.code = v.code
WHERE v.type_code = 'task_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'task_status', t.code, 'CUTOVER', 'migration', 'from ref_task_status'
FROM ref_task_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'task_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- task_priority (TKP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('task_priority', 'Task priority', 'Cut over from ref_task_priority', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'task_priority', code FROM ref_task_priority;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_task_priority t ON t.code = v.code
WHERE v.type_code = 'task_priority'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'task_priority', t.code, 'CUTOVER', 'migration', 'from ref_task_priority'
FROM ref_task_priority t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'task_priority' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- queue_status (QUS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('queue_status', 'Queue status', 'Cut over from ref_queue_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'queue_status', code FROM ref_queue_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_queue_status t ON t.code = v.code
WHERE v.type_code = 'queue_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'queue_status', t.code, 'CUTOVER', 'migration', 'from ref_queue_status'
FROM ref_queue_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'queue_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- queue_type (QUT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('queue_type', 'Queue type', 'Cut over from ref_queue_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'queue_type', code FROM ref_queue_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_queue_type t ON t.code = v.code
WHERE v.type_code = 'queue_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'queue_type', t.code, 'CUTOVER', 'migration', 'from ref_queue_type'
FROM ref_queue_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'queue_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- notification_type (NFT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('notification_type', 'Notification type', 'Cut over from ref_notification_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'notification_type', code FROM ref_notification_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_notification_type t ON t.code = v.code
WHERE v.type_code = 'notification_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'notification_type', t.code, 'CUTOVER', 'migration', 'from ref_notification_type'
FROM ref_notification_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'notification_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- notification_result (NFR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('notification_result', 'Notification result', 'Cut over from ref_notification_result', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'notification_result', code FROM ref_notification_result;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_notification_result t ON t.code = v.code
WHERE v.type_code = 'notification_result'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'notification_result', t.code, 'CUTOVER', 'migration', 'from ref_notification_result'
FROM ref_notification_result t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'notification_result' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- message_status (MSS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('message_status', 'Message status', 'Cut over from ref_message_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'message_status', code FROM ref_message_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_message_status t ON t.code = v.code
WHERE v.type_code = 'message_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'message_status', t.code, 'CUTOVER', 'migration', 'from ref_message_status'
FROM ref_message_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'message_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- message_channel (MSC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('message_channel', 'Message channel', 'Cut over from ref_message_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'message_channel', code FROM ref_message_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_message_channel t ON t.code = v.code
WHERE v.type_code = 'message_channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'message_channel', t.code, 'CUTOVER', 'migration', 'from ref_message_channel'
FROM ref_message_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'message_channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- event_type (EVT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('event_type', 'Event type', 'Cut over from ref_event_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'event_type', code FROM ref_event_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_event_type t ON t.code = v.code
WHERE v.type_code = 'event_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'event_type', t.code, 'CUTOVER', 'migration', 'from ref_event_type'
FROM ref_event_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'event_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- event_status (EVS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('event_status', 'Event status', 'Cut over from ref_event_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'event_status', code FROM ref_event_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_event_status t ON t.code = v.code
WHERE v.type_code = 'event_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'event_status', t.code, 'CUTOVER', 'migration', 'from ref_event_status'
FROM ref_event_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'event_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- audit_result (AUR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('audit_result', 'Audit result', 'Cut over from ref_audit_result', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'audit_result', code FROM ref_audit_result;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_audit_result t ON t.code = v.code
WHERE v.type_code = 'audit_result'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'audit_result', t.code, 'CUTOVER', 'migration', 'from ref_audit_result'
FROM ref_audit_result t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'audit_result' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- audit_source (AUS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('audit_source', 'Audit source', 'Cut over from ref_audit_source', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'audit_source', code FROM ref_audit_source;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_audit_source t ON t.code = v.code
WHERE v.type_code = 'audit_source'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'audit_source', t.code, 'CUTOVER', 'migration', 'from ref_audit_source'
FROM ref_audit_source t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'audit_source' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- audit_severity (AUV)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('audit_severity', 'Audit severity', 'Cut over from ref_audit_severity', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'audit_severity', code FROM ref_audit_severity;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_audit_severity t ON t.code = v.code
WHERE v.type_code = 'audit_severity'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'audit_severity', t.code, 'CUTOVER', 'migration', 'from ref_audit_severity'
FROM ref_audit_severity t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'audit_severity' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_layout (RLY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_layout', 'Report layout', 'Cut over from ref_report_layout', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_layout', code FROM ref_report_layout;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_layout t ON t.code = v.code
WHERE v.type_code = 'report_layout'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_layout', t.code, 'CUTOVER', 'migration', 'from ref_report_layout'
FROM ref_report_layout t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_layout' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_column (RCL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_column', 'Report column', 'Cut over from ref_report_column', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_column', code FROM ref_report_column;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_column t ON t.code = v.code
WHERE v.type_code = 'report_column'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_column', t.code, 'CUTOVER', 'migration', 'from ref_report_column'
FROM ref_report_column t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_column' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_filter (RFL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_filter', 'Report filter', 'Cut over from ref_report_filter', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_filter', code FROM ref_report_filter;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_filter t ON t.code = v.code
WHERE v.type_code = 'report_filter'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_filter', t.code, 'CUTOVER', 'migration', 'from ref_report_filter'
FROM ref_report_filter t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_filter' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_parameter (RPM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_parameter', 'Report parameter', 'Cut over from ref_report_parameter', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_parameter', code FROM ref_report_parameter;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_parameter t ON t.code = v.code
WHERE v.type_code = 'report_parameter'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_parameter', t.code, 'CUTOVER', 'migration', 'from ref_report_parameter'
FROM ref_report_parameter t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_parameter' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_schedule (RSD)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_schedule', 'Report schedule', 'Cut over from ref_report_schedule', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_schedule', code FROM ref_report_schedule;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_schedule t ON t.code = v.code
WHERE v.type_code = 'report_schedule'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_schedule', t.code, 'CUTOVER', 'migration', 'from ref_report_schedule'
FROM ref_report_schedule t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_schedule' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_delivery (RDV)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_delivery', 'Report delivery', 'Cut over from ref_report_delivery', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_delivery', code FROM ref_report_delivery;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_delivery t ON t.code = v.code
WHERE v.type_code = 'report_delivery'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_delivery', t.code, 'CUTOVER', 'migration', 'from ref_report_delivery'
FROM ref_report_delivery t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_delivery' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- export_schedule (ESD)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('export_schedule', 'Export schedule', 'Cut over from ref_export_schedule', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'export_schedule', code FROM ref_export_schedule;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_export_schedule t ON t.code = v.code
WHERE v.type_code = 'export_schedule'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'export_schedule', t.code, 'CUTOVER', 'migration', 'from ref_export_schedule'
FROM ref_export_schedule t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'export_schedule' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- export_delivery (EDV)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('export_delivery', 'Export delivery', 'Cut over from ref_export_delivery', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'export_delivery', code FROM ref_export_delivery;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_export_delivery t ON t.code = v.code
WHERE v.type_code = 'export_delivery'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'export_delivery', t.code, 'CUTOVER', 'migration', 'from ref_export_delivery'
FROM ref_export_delivery t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'export_delivery' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- file_source (FSR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('file_source', 'File source', 'Cut over from ref_file_source', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'file_source', code FROM ref_file_source;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_file_source t ON t.code = v.code
WHERE v.type_code = 'file_source'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'file_source', t.code, 'CUTOVER', 'migration', 'from ref_file_source'
FROM ref_file_source t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'file_source' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- file_status (FST)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('file_status', 'File status', 'Cut over from ref_file_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'file_status', code FROM ref_file_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_file_status t ON t.code = v.code
WHERE v.type_code = 'file_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'file_status', t.code, 'CUTOVER', 'migration', 'from ref_file_status'
FROM ref_file_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'file_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- file_direction (FDR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('file_direction', 'File direction', 'Cut over from ref_file_direction', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'file_direction', code FROM ref_file_direction;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_file_direction t ON t.code = v.code
WHERE v.type_code = 'file_direction'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'file_direction', t.code, 'CUTOVER', 'migration', 'from ref_file_direction'
FROM ref_file_direction t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'file_direction' AND a.value_code = t.code AND a.action = 'CUTOVER'
);


-- Phase 2 slice: backup and restore tracking.

CREATE TABLE IF NOT EXISTS backup_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    backup_type VARCHAR(40) NOT NULL,
    target VARCHAR(100) NOT NULL,
    status ENUM('RUNNING','VERIFIED','RESTORED','FAILED') NOT NULL DEFAULT 'RUNNING',
    started_by VARCHAR(100) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verified_by VARCHAR(100) NULL,
    verified_at DATETIME NULL,
    restored_by VARCHAR(100) NULL,
    restored_at DATETIME NULL,
    INDEX idx_backup_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS backup_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    backup_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_backup_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 2 slice: secret rotation tracking.

CREATE TABLE IF NOT EXISTS secret_rotation (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    secret_name VARCHAR(64) NOT NULL,
    next_rotation_at DATETIME NOT NULL,
    overlap_seconds INT NOT NULL DEFAULT 300,
    status ENUM('SCHEDULED','ROTATED','VERIFIED') NOT NULL DEFAULT 'SCHEDULED',
    scheduled_by VARCHAR(100) NOT NULL,
    scheduled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    rotated_by VARCHAR(100) NULL,
    rotated_at DATETIME NULL,
    verified_by VARCHAR(100) NULL,
    verified_at DATETIME NULL,
    INDEX idx_secret_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS secret_rotation_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    secret_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_secret_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 2 slice: disaster recovery tracking.

CREATE TABLE IF NOT EXISTS dr_plan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    plan_name VARCHAR(100) NOT NULL,
    rto_minutes INT NOT NULL,
    rpo_minutes INT NOT NULL,
    status ENUM('ACTIVE','VERIFIED') NOT NULL DEFAULT 'ACTIVE',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verified_at DATETIME NULL,
    INDEX idx_dr_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dr_test (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    plan_id BIGINT NOT NULL,
    outcome VARCHAR(40) NOT NULL,
    tested_by VARCHAR(100) NOT NULL,
    tested_at DATETIME NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dr_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    plan_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_dr_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 2 slice: capacity planning tracking.

CREATE TABLE IF NOT EXISTS capacity_plan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    plan_name VARCHAR(100) NOT NULL,
    threshold VARCHAR(40) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    status ENUM('ACTIVE','RETIRED') NOT NULL DEFAULT 'ACTIVE',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_capacity_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS capacity_breach (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    plan_id BIGINT NOT NULL,
    observed VARCHAR(40) NOT NULL,
    breached_at DATETIME NOT NULL,
    recorded_by VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS capacity_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    plan_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_capacity_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 2 slice: audit retention tracking.

CREATE TABLE IF NOT EXISTS audit_retention_policy (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    policy_name VARCHAR(64) NOT NULL,
    retention_days INT NOT NULL,
    status ENUM('ACTIVE','RETIRED') NOT NULL DEFAULT 'ACTIVE',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_audit_retention_policy (policy_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_retention_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    policy_id BIGINT NOT NULL,
    archived_count BIGINT NOT NULL DEFAULT 0,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'COMPLETED',
    run_by VARCHAR(100) NOT NULL,
    run_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_retention_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_retention_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 2 slice: audit retention tracking.

CREATE TABLE IF NOT EXISTS audit_retention_policy (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    policy_name VARCHAR(64) NOT NULL,
    retention_days INT NOT NULL,
    status ENUM('ACTIVE','RETIRED') NOT NULL DEFAULT 'ACTIVE',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_audit_retention_policy (policy_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_retention_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    policy_id BIGINT NOT NULL,
    archived_count BIGINT NOT NULL DEFAULT 0,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'COMPLETED',
    run_by VARCHAR(100) NOT NULL,
    run_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_retention_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_retention_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 2 slice: compliance audit tracking.

CREATE TABLE IF NOT EXISTS compliance_finding (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    severity ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT NULL DEFAULT 'MEDIUM',
    status ENUM('OPEN','CLOSED') NOT NULL DEFAULT 'OPEN',
    raised_by VARCHAR(100) NOT NULL,
    raised_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    closed_at DATETIME NULL,
    INDEX idx_compliance_finding_status (status, severity)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compliance_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    finding_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_compliance_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 2 slice: vendor compliance tracking.

CREATE TABLE IF NOT EXISTS vendor_compliance (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    vendor_code VARCHAR(64) NOT NULL,
    status ENUM('PENDING','APPROVED') NOT NULL DEFAULT 'PENDING',
    assessed_by VARCHAR(100) NOT NULL,
    assessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_by VARCHAR(100) NULL,
    approved_at DATETIME NULL,
    INDEX idx_vendor_compliance_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vendor_compliance_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    assessment_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_vendor_compliance_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 2 slice: data quality tracking.

CREATE TABLE IF NOT EXISTS data_quality_rule (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rule_name VARCHAR(64) NOT NULL,
    severity ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'MEDIUM',
    status ENUM('ACTIVE','RETIRED') NOT NULL DEFAULT 'ACTIVE',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_data_quality_rule (rule_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS data_quality_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rule_id BIGINT NOT NULL,
    findings BIGINT NOT NULL DEFAULT 0,
    status ENUM('RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'COMPLETED',
    run_by VARCHAR(100) NOT NULL,
    run_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS data_quality_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    rule_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_data_quality_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 2 slice: notification audit tracking.

CREATE TABLE IF NOT EXISTS notification_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    channel VARCHAR(20) NOT NULL,
    recipient VARCHAR(100) NOT NULL,
    status ENUM('PENDING','SENDING','SENT','FAILED','DEAD') NOT NULL DEFAULT 'PENDING',
    retry_count INT NOT NULL DEFAULT 0,
    enqueued_by VARCHAR(100) NOT NULL,
    enqueued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notification_audit_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notification_audit_entry (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    audit_id BIGINT NOT NULL,
    event VARCHAR(40) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Phase 2 slice: notification audit tracking.

CREATE TABLE IF NOT EXISTS notification_delivery (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    channel VARCHAR(20) NOT NULL,
    recipient VARCHAR(100) NOT NULL,
    status ENUM('PENDING','SENDING','SENT','FAILED','DEAD') NOT NULL DEFAULT 'PENDING',
    retry_count INT NOT NULL DEFAULT 0,
    enqueued_by VARCHAR(100) NOT NULL,
    enqueued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notification_delivery_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notification_delivery_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    entry_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notification_delivery_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

-- Phase 2 slice: report audit tracking.

CREATE TABLE IF NOT EXISTS report_execution_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    report_name VARCHAR(64) NOT NULL,
    duration_ms INT NOT NULL DEFAULT 0,
    status ENUM('OK','FAILED') NOT NULL DEFAULT 'OK',
    recorded_by VARCHAR(100) NOT NULL,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_report_execution_audit_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_execution_audit_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    run_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_report_execution_audit_audit_actor (actor_email, created_at)
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
('0089_security_data_cert'),
('0090_observability'),
('0091_incident_change'),
('0092_cutover'),
('0093_cutover'),
('0094_backup_restore'),
('0095_secret_rotation'),
('0096_disaster_recovery'),
('0097_capacity_plan'),
('0098_audit_retention'),
('0099_compliance_audit'),
('0100_vendor_compliance'),
('0101_data_quality'),
('0102_notification_audit'),
('0103_report_audit');


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
