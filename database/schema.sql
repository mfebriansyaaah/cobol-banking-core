-- E-Wallet Enterprise Secure Database Schema
-- Target: MySQL 8.0 / MariaDB 11 (InnoDB, utf8mb4)
-- Purpose: Ensuring Financial Integrity and Strict Identity
-- Version: baseline-0036 (fresh-install snapshot; see the baseline block by
--   schema_migrations below, and docs/SCHEMA_POLICY.md for the change process)
-- Note: versioned changes live in database/migrations/NNN_*.sql; apply them
--       with database/migrate.sh. See docs/STATUS.md for schema details.
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
    account_type ENUM('SAVINGS', 'CHECKING', 'INVESTMENT', 'FEE_INCOME') DEFAULT 'SAVINGS',  -- FEE_INCOME: bank-owned fee collection account (one active per currency)
    balance DECIMAL(18, 4) NOT NULL DEFAULT 0.0000 CHECK (balance >= 0),
    status ENUM('ACTIVE', 'FROZEN', 'CLOSED') DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_acc_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_acc_curr FOREIGN KEY (currency_id) REFERENCES currencies(currency_id),
    UNIQUE KEY unique_user_currency (user_id, currency_id)
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
    exchange_rate DECIMAL(18, 6) NULL,
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
    exchange_rate DECIMAL(18, 6) NULL,
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

-- 9d. Recorded reconciliation runs (immutable) and exception findings
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
('0036_disputes');


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
