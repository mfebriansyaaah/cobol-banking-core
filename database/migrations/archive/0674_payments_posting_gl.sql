-- Fase 1 (payments 10/10): real posting for clearing settle + hold capture.
-- 1) Bank-owned CLEARING suspense account type (one ACTIVE per currency,
--    mirroring FEE_INCOME/FX_PNL via control_slot): hold captures credit
--    this account while debiting the customer account, so captured funds
--    stay conserved inside the customer subledger.
-- 2) payment_clearing.gl_journal_id: each PMC_SETTLE posts one balanced GL
--    journal (DEBIT 1200 Clearing suspense / CREDIT 2110 Settlement payable)
--    and links it; the journal description 'PMC_SETTLE:<ref>:<amt>' makes a
--    retried settle idempotent (re-link, no double post).
-- 3) payment_hold.journal_id: PHL_CAPTURE posts its two ledger legs under one
--    journal_entries row (txn_ref 'PHL-<id>') and links it.
-- 4) GL accounts 1200/2110 for the clearing settlement journal.
ALTER TABLE accounts MODIFY COLUMN account_type
    ENUM('SAVINGS','CHECKING','INVESTMENT','FEE_INCOME','FX_PNL','CLEARING') DEFAULT 'SAVINGS';
ALTER TABLE accounts MODIFY COLUMN control_slot VARCHAR(32) GENERATED ALWAYS AS
  (CASE WHEN status = 'ACTIVE' AND account_type IN ('FX_PNL','FEE_INCOME','CLEARING')
        THEN CONCAT(currency_id, '/', account_type) ELSE NULL END) STORED;

ALTER TABLE payment_clearing
    ADD COLUMN IF NOT EXISTS gl_journal_id INT NULL AFTER settled_at;
CREATE INDEX IF NOT EXISTS idx_payment_clearing_gl ON payment_clearing (gl_journal_id);

ALTER TABLE payment_hold
    ADD COLUMN IF NOT EXISTS journal_id BIGINT NULL AFTER released_at;
CREATE INDEX IF NOT EXISTS idx_payment_hold_journal ON payment_hold (journal_id);

INSERT IGNORE INTO gl_account (account_code, name, account_type, normal_side, is_active) VALUES
('1200', 'Clearing suspense', 'ASSET', 'DEBIT', TRUE),
('2110', 'Settlement payable', 'LIABILITY', 'CREDIT', TRUE);
