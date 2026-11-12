-- D3 cards: card lifecycle, authorization/capture, credit balance and history.

ALTER TABLE card_account
    ADD COLUMN IF NOT EXISTS masked_pan VARCHAR(25) NULL;
ALTER TABLE card_account
    ADD COLUMN IF NOT EXISTS expiry_date DATE NULL;
ALTER TABLE card_account
    ADD COLUMN IF NOT EXISTS available_limit DECIMAL(18,4) NOT NULL DEFAULT 0;
ALTER TABLE card_account
    ADD COLUMN IF NOT EXISTS balance DECIMAL(18,4) NOT NULL DEFAULT 0;
ALTER TABLE card_account
    ADD COLUMN IF NOT EXISTS replaced_by BIGINT NULL;

-- Backfill available credit for cards issued before this migration.
UPDATE card_account
   SET available_limit = limit_amount
 WHERE available_limit = 0 AND limit_amount > 0;

CREATE TABLE IF NOT EXISTS card_transaction (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    card_id BIGINT NOT NULL,
    auth_ref VARCHAR(64) NOT NULL,
    txn_type ENUM('AUTHORIZATION','CAPTURE','REPAYMENT','REVERSAL') NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    currency CHAR(3) NOT NULL,
    merchant VARCHAR(100) NULL,
    status ENUM('AUTHORIZED','CAPTURED','DECLINED','REVERSED') NOT NULL DEFAULT 'AUTHORIZED',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_card_auth_ref (auth_ref),
    INDEX idx_card_txn (card_id, created_at),
    CONSTRAINT fk_card_txn FOREIGN KEY (card_id)
        REFERENCES card_account (id) ON DELETE CASCADE
) ENGINE=InnoDB;
