-- Migration 0012: cap code-guessing attempts per verification code.
-- Every failed VERIFY_EMAIL / RESET_PASSWORD / CONFIRM_EMAIL_CHANGE against a
-- live code increments `attempts`; at the cap the code is burned and a fresh
-- one must be requested.
ALTER TABLE verification_logs ADD COLUMN attempts INT NOT NULL DEFAULT 0 AFTER is_used;
