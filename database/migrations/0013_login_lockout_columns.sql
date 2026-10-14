-- Migration 0013: track login failures on the user row.
-- Lockout is now read and cleared via these columns instead of counting (and
-- deleting) audit_trail rows, so audit stays append-only.
ALTER TABLE users
    ADD COLUMN failed_logins INT NOT NULL DEFAULT 0 AFTER token_version,
    ADD COLUMN locked_until TIMESTAMP NULL DEFAULT NULL AFTER failed_logins;
