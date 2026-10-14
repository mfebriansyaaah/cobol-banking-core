-- Migration 0014: per-user TOTP second factor.
-- mfa_secret holds the base32 shared secret (set while enrolling); mfa_enabled
-- turns the second factor on once the user confirms a code.
ALTER TABLE users
    ADD COLUMN mfa_secret VARCHAR(64) NULL DEFAULT NULL AFTER locked_until,
    ADD COLUMN mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE AFTER mfa_secret;
