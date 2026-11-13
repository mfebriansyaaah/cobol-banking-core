-- Migration 0045: risk-based step-up policy for customer actions (ADR 0079).
-- The requirement is owner-controlled data: an action is catalogued here
-- with a minimum amount and an enabled flag. The core answers
-- STEP_UP_REQUIRED; the gateway enforces it by verifying the short-lived
-- proof minted by POST /auth/step-up.
--
-- Seed: email change and MFA disable always require a proof. Transfer is
-- catalogued but disabled until the owner sets a threshold (enabling it with
-- a zero minimum would interrupt every transfer).
CREATE TABLE IF NOT EXISTS step_up_policy (
    action VARCHAR(30) NOT NULL PRIMARY KEY,
    min_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    enabled BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

INSERT IGNORE INTO step_up_policy (action, min_amount, enabled) VALUES
    ('REQ_EMAIL_CHANGE', 0, TRUE),
    ('MFA_DISABLE', 0, TRUE),
    ('TRANSFER', 0, FALSE);
