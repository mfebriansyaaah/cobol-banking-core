-- PR-301: Merchant Acquiring — settlement batch + items.
-- Extends merchant_settlement with merchant link, amounts, payout and GL.

ALTER TABLE merchant_settlement
    ADD COLUMN IF NOT EXISTS merchant_id BIGINT NULL AFTER settlement_ref,
    ADD COLUMN IF NOT EXISTS period_start DATE NULL AFTER merchant_id,
    ADD COLUMN IF NOT EXISTS period_end DATE NULL AFTER period_start,
    ADD COLUMN IF NOT EXISTS gross_amount DECIMAL(18,4) NOT NULL DEFAULT 0 AFTER settlement_amount,
    ADD COLUMN IF NOT EXISTS fee_amount DECIMAL(18,4) NOT NULL DEFAULT 0 AFTER gross_amount,
    ADD COLUMN IF NOT EXISTS net_amount DECIMAL(18,4) NOT NULL DEFAULT 0 AFTER fee_amount,
    ADD COLUMN IF NOT EXISTS currency CHAR(3) NOT NULL DEFAULT 'IDR' AFTER net_amount,
    ADD COLUMN IF NOT EXISTS settlement_account_id INT NULL AFTER currency,
    ADD COLUMN IF NOT EXISTS payment_clearing_ref VARCHAR(40) NULL AFTER settlement_account_id,
    ADD COLUMN IF NOT EXISTS gl_journal_id INT NULL AFTER payment_clearing_ref;

-- Broaden status while keeping legacy OPEN/ACTIVE/SETTLED/DELETED rows valid.
ALTER TABLE merchant_settlement
    MODIFY COLUMN status ENUM('OPEN','ACTIVE','SETTLED','DELETED','SCHEDULED','PAID','FAILED','CANCELLED')
    NOT NULL DEFAULT 'OPEN';

CREATE INDEX IF NOT EXISTS idx_merchant_settlement_merchant ON merchant_settlement (merchant_id, status);

CREATE TABLE IF NOT EXISTS merchant_settlement_item (
    item_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    settlement_id BIGINT NOT NULL,
    merchant_txn_id BIGINT NOT NULL,
    gross_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    fee_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    net_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_settlement_item_settlement FOREIGN KEY (settlement_id)
        REFERENCES merchant_settlement (id) ON DELETE CASCADE,
    CONSTRAINT fk_settlement_item_txn FOREIGN KEY (merchant_txn_id)
        REFERENCES merchant_transaction (merchant_txn_id) ON DELETE CASCADE,
    UNIQUE KEY uq_settlement_item_txn (settlement_id, merchant_txn_id),
    INDEX idx_settlement_item_settlement (settlement_id),
    CHECK (gross_amount >= 0),
    CHECK (fee_amount >= 0)
) ENGINE=InnoDB;
