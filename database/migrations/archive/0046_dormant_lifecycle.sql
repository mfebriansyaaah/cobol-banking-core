-- Migration 0046: dormant account lifecycle (ADR 0080).
-- Two phases, so a customer is warned before any restriction:
--   MARK_DORMANT    flags accounts whose last sign-in is older than
--                   DORMANT_AFTER_DAYS and queues a notice;
--   SUSPEND_DORMANT suspends the flagged accounts after DORMANT_GRACE_DAYS,
--                   provided they still have not signed in.
-- SUPER_ADMIN accounts are never auto-suspended: the access-review workflow
-- owns privileged accounts, and the last-admin guard must not be bypassed by
-- a bulk update.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS dormant_notified_at TIMESTAMP NULL DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_users_dormant
    ON users (status, last_login_at);
