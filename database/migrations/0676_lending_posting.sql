-- Lending Fase 1: real posting for loan disburse/repay + deposit settle.
-- 1) Bank-owned LOAN_BOOK / DEPOSIT_POOL suspense accounts (one ACTIVE per
--    currency via control_slot, mirroring CLEARING/FEE_INCOME): the
--    counterparty that keeps every lending leg balanced inside the
--    customer subledger.
-- 2) Linkage columns for the three postings (subledger journal +
--    GL journal each).
-- 3) GL accounts for the bank side of the postings.
ALTER TABLE accounts MODIFY COLUMN account_type
    ENUM('SAVINGS','CHECKING','INVESTMENT','FEE_INCOME','FX_PNL','CLEARING','LOAN_BOOK','DEPOSIT_POOL') DEFAULT 'SAVINGS';
ALTER TABLE accounts MODIFY COLUMN control_slot VARCHAR(32) GENERATED ALWAYS AS
  (CASE WHEN status = 'ACTIVE' AND account_type IN ('FX_PNL','FEE_INCOME','CLEARING','LOAN_BOOK','DEPOSIT_POOL')
        THEN CONCAT(currency_id, '/', account_type) ELSE NULL END) STORED;

ALTER TABLE loan_application
    ADD COLUMN IF NOT EXISTS journal_id BIGINT NULL AFTER disbursed_at,
    ADD COLUMN IF NOT EXISTS gl_journal_id INT NULL AFTER journal_id;
CREATE INDEX IF NOT EXISTS idx_loan_app_journal ON loan_application (journal_id);
CREATE INDEX IF NOT EXISTS idx_loan_app_gl ON loan_application (gl_journal_id);
ALTER TABLE loan_application
    ADD CONSTRAINT fk_loan_app_journal FOREIGN KEY (journal_id) REFERENCES journal_entries (journal_id),
    ADD CONSTRAINT fk_loan_app_gl FOREIGN KEY (gl_journal_id) REFERENCES gl_journal (id);

ALTER TABLE loan_repayment
    ADD COLUMN IF NOT EXISTS journal_id BIGINT NULL AFTER paid_at,
    ADD COLUMN IF NOT EXISTS gl_journal_id INT NULL AFTER journal_id;
CREATE INDEX IF NOT EXISTS idx_loan_repay_journal ON loan_repayment (journal_id);
CREATE INDEX IF NOT EXISTS idx_loan_repay_gl ON loan_repayment (gl_journal_id);
ALTER TABLE loan_repayment
    ADD CONSTRAINT fk_loan_repay_journal FOREIGN KEY (journal_id) REFERENCES journal_entries (journal_id),
    ADD CONSTRAINT fk_loan_repay_gl FOREIGN KEY (gl_journal_id) REFERENCES gl_journal (id);

ALTER TABLE deposit_account
    ADD COLUMN IF NOT EXISTS journal_id BIGINT NULL AFTER maturity_date,
    ADD COLUMN IF NOT EXISTS gl_journal_id INT NULL AFTER journal_id;
CREATE INDEX IF NOT EXISTS idx_deposit_journal ON deposit_account (journal_id);
CREATE INDEX IF NOT EXISTS idx_deposit_gl ON deposit_account (gl_journal_id);
ALTER TABLE deposit_account
    ADD CONSTRAINT fk_deposit_journal FOREIGN KEY (journal_id) REFERENCES journal_entries (journal_id),
    ADD CONSTRAINT fk_deposit_gl FOREIGN KEY (gl_journal_id) REFERENCES gl_journal (id);

INSERT IGNORE INTO gl_account (account_code, name, account_type, normal_side, is_active) VALUES
('1300', 'Loans receivable', 'ASSET', 'DEBIT', TRUE),
('2120', 'Deposits payable', 'LIABILITY', 'CREDIT', TRUE);
