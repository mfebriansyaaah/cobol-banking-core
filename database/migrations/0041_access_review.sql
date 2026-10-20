-- Migration 0041: access review and attestation (ADR 0073).
-- A-P0-ACCESS is "partial" with the explicit gap "no access reviews": the
-- runtime controls (role hierarchy, last-admin guard, maker-checker, step-up)
-- restrict who may act, but nothing re-asks whether a privileged account
-- still needs its access.
--
-- A review is a point-in-time snapshot of every privileged account
-- (MANAGER, SUPER_ADMIN) with the role, status, MFA state, and last sign-in
-- captured when the review opened. The items are evidence of that moment,
-- so they deliberately carry no foreign key to users: deleting the reviewed
-- account must not destroy the review record. Only the review itself is
-- referenced, so a review and its items move together.
--
-- last_login_at is written on a successful login so a reviewer can see how
-- long a privileged account has been dormant.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP NULL DEFAULT NULL;

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
