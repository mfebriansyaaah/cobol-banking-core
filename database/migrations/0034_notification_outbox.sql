-- Migration 0034: transactional notification outbox.
-- The core writes one row per notification inside the same transaction as
-- the business action that requires it (signup/resend/password-reset/
-- email-change codes, email-changed notices), so a committed action can
-- never lose its notification. A worker claims due rows, sends them, and
-- marks the outcome; bounded retries with backoff, then dead-letter.
-- Codes live only in this table and the delivery itself: read APIs never
-- expose them, and operational logs carry ids/recipients, never codes.
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
