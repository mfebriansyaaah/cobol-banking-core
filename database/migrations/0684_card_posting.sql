-- Card Fase 1: real posting for CAPTURE, REPAY and REVERSAL.
-- 1) Bank-owned CARD_RECEIVABLE / MERCHANT_PAYABLE suspense accounts (one
--    ACTIVE per currency via control_slot, mirroring LOAN_BOOK/DEPOSIT_POOL):
--    the counterparties that keep every card leg balanced inside the
--    customer subledger. CAPTURE books cardholder debt against merchant
--    payable; REPAY collects it from the customer wallet; REVERSAL unwinds.
-- 2) Linkage columns for the three postings (subledger journal + GL
--    journal each). AUTHORIZE stays memo-only: a hold locks limit, it moves
--    no money.
-- 3) GL accounts for the bank side of the postings.
ALTER TABLE accounts MODIFY COLUMN account_type
    ENUM('SAVINGS','CHECKING','INVESTMENT','FEE_INCOME','FX_PNL','CLEARING','LOAN_BOOK','DEPOSIT_POOL','CARD_RECEIVABLE','MERCHANT_PAYABLE') DEFAULT 'SAVINGS';
ALTER TABLE accounts MODIFY COLUMN control_slot VARCHAR(32) GENERATED ALWAYS AS
  (CASE WHEN status = 'ACTIVE' AND account_type IN ('FX_PNL','FEE_INCOME','CLEARING','LOAN_BOOK','DEPOSIT_POOL','CARD_RECEIVABLE','MERCHANT_PAYABLE')
        THEN CONCAT(currency_id, '/', account_type) ELSE NULL END) STORED;

ALTER TABLE card_transaction
    ADD COLUMN IF NOT EXISTS journal_id BIGINT NULL AFTER status,
    ADD COLUMN IF NOT EXISTS gl_journal_id INT NULL AFTER journal_id;
CREATE INDEX IF NOT EXISTS idx_card_txn_journal ON card_transaction (journal_id);
CREATE INDEX IF NOT EXISTS idx_card_txn_gl ON card_transaction (gl_journal_id);
ALTER TABLE card_transaction
    ADD CONSTRAINT fk_card_txn_journal FOREIGN KEY (journal_id) REFERENCES journal_entries (journal_id),
    ADD CONSTRAINT fk_card_txn_gl FOREIGN KEY (gl_journal_id) REFERENCES gl_journal (id);

INSERT IGNORE INTO gl_account (account_code, name, account_type, normal_side, is_active) VALUES
('1310', 'Cards receivable', 'ASSET', 'DEBIT', TRUE),
('2130', 'Merchants payable', 'LIABILITY', 'CREDIT', TRUE);
