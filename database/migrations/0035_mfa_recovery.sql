-- Migration 0035: MFA backup codes and assisted recovery.
-- 1) mfa_backup_codes: single-use numeric backup codes, PBKDF2-hashed like
--    passwords (never stored or logged in clear). A code is accepted only at
--    login/step-up when TOTP is unavailable, and burns on use. Regenerating
--    replaces the whole set; disabling/resetting MFA clears it.
-- 2) mfa_recovery_requests: lost-device recovery with re-proofing and
--    approval. REQUEST (password-checked, neutral) enqueues an email code;
--    CONFIRM marks the request VERIFIED; an admin APPROVEs (clears MFA and
--    backup codes, burns the code, notifies) or REJECTs. All transitions
--    are audited; evidence survives resolution via the run-style link.
-- 3) verification_logs purpose gains MFA_RECOVERY for the emailed code.
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

ALTER TABLE verification_logs MODIFY COLUMN purpose
    ENUM('SIGNUP', 'EMAIL_CHANGE', 'PASSWORD_RESET', 'MFA_RECOVERY') NOT NULL;
