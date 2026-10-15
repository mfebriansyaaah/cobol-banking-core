-- Migration 0027: ledger durability and immutability.
-- 1) Immutable archive: before an account (or a user, via the cascade to
--    accounts) is deleted, its ledger rows are copied into `ledger_archive`
--    (no FK), so ledger history survives instead of being cascaded away.
-- 2) Ledger rows are append-only: UPDATE is refused by a trigger.
-- 3) Defensive constraints: amount must be positive, and a posting
--    (txn_ref, account_id, type) is unique.
CREATE TABLE IF NOT EXISTS ledger_archive (
    ledger_id BIGINT PRIMARY KEY,
    txn_ref VARCHAR(50) NOT NULL,
    account_id INT NOT NULL,
    amount DECIMAL(18, 4) NOT NULL,
    type ENUM('CREDIT', 'DEBIT') NOT NULL,
    currency_id INT NOT NULL,
    from_email VARCHAR(100) NULL,
    description VARCHAR(255),
    exchange_rate DECIMAL(18, 6) NULL,
    created_at TIMESTAMP NULL,
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_ledger_archive_account (account_id)
) ENGINE=InnoDB;

ALTER TABLE ledger ADD CONSTRAINT chk_ledger_amount CHECK (amount >= 0);

DELIMITER //
CREATE TRIGGER IF NOT EXISTS trg_ledger_no_update BEFORE UPDATE ON ledger
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ledger is append-only (no UPDATE)';
END//

CREATE TRIGGER IF NOT EXISTS trg_ledger_archive_account BEFORE DELETE ON accounts
FOR EACH ROW
BEGIN
    INSERT IGNORE INTO ledger_archive (ledger_id, txn_ref, account_id, amount, type, currency_id, from_email, description, exchange_rate, created_at)
    SELECT ledger_id, txn_ref, account_id, amount, type, currency_id, from_email, description, exchange_rate, created_at
    FROM ledger WHERE account_id = OLD.account_id;
END//
DELIMITER ;
