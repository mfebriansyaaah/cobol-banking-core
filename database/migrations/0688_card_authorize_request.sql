-- Idempotency for CARD_AUTHORIZE (arch9 WP-11): the legacy request row
-- backing the unified mirror for the authorize scope.
-- Same shape as the other *_request tables (entity + key + amount, PENDING
-- until the action completes, DONE rows immutable). The adopted auth_ref is
-- written by the action itself inside its transaction (see ACTION-AUTHORIZE);
-- IDEM-LINK is not used because WS-IDEM-LINKVAL (X(20)) cannot carry a 64-char ref.
CREATE TABLE IF NOT EXISTS card_authorize_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    card_id BIGINT NOT NULL,
    idempotency_key VARCHAR(64) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT '',
    merchant VARCHAR(100) NOT NULL DEFAULT '',
    auth_ref VARCHAR(64) NULL,
    status ENUM('PENDING','DONE') NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_card_auth_idem (card_id, idempotency_key),
    KEY idx_card_auth_status (status),
    CONSTRAINT fk_card_auth_request_card FOREIGN KEY (card_id)
        REFERENCES card_account(id) ON DELETE CASCADE
) ENGINE=InnoDB;
