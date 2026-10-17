-- Migration 0030: journal header for every posting.
-- A journal_entries row is the double-entry header: one row per posting
-- event (TRANSFER or REVERSAL) with its business date, source, reference,
-- and initiator. Ledger legs and audit rows point at it, so any movement is
-- traceable from instruction through journal, legs, and audit. Journal rows
-- are never deleted; ledger/audit archives carry the link for history that
-- outlives its account.
CREATE TABLE IF NOT EXISTS journal_entries (
    journal_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    txn_ref VARCHAR(50) NOT NULL,
    source ENUM('TRANSFER','REVERSAL') NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    value_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_journal_ref (txn_ref)
) ENGINE=InnoDB;

ALTER TABLE ledger ADD COLUMN journal_id BIGINT NULL,
    ADD CONSTRAINT fk_ledger_journal FOREIGN KEY (journal_id)
        REFERENCES journal_entries(journal_id);
ALTER TABLE ledger_archive ADD COLUMN journal_id BIGINT NULL;
ALTER TABLE audit_trail ADD COLUMN journal_id BIGINT NULL;
ALTER TABLE audit_trail_archive ADD COLUMN journal_id BIGINT NULL;

DELIMITER //
DROP TRIGGER IF EXISTS trg_ledger_archive_account//
CREATE TRIGGER trg_ledger_archive_account BEFORE DELETE ON accounts
FOR EACH ROW
BEGIN
    INSERT IGNORE INTO ledger_archive (ledger_id, txn_ref, account_id, amount, type, currency_id, from_email, description, exchange_rate, journal_id, created_at)
    SELECT ledger_id, txn_ref, account_id, amount, type, currency_id, from_email, description, exchange_rate, journal_id, created_at
    FROM ledger WHERE account_id = OLD.account_id;
END//
DROP TRIGGER IF EXISTS trg_audit_snapshot_user_delete//
CREATE TRIGGER trg_audit_snapshot_user_delete BEFORE DELETE ON users
FOR EACH ROW
BEGIN
    INSERT IGNORE INTO audit_trail_archive (audit_id, user_id, actor_id, action, entity_type, entity_id, detail, status, journal_id, created_at)
    SELECT audit_id, user_id, actor_id, action, entity_type, entity_id, detail, status, journal_id, created_at
    FROM audit_trail WHERE user_id = OLD.id;
END//
DELIMITER ;
