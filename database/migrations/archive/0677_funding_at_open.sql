-- Lending Fase 2: funding at open.
-- DEP_OPEN now moves real money (customer wallet debit / DEPOSIT_POOL
-- credit) plus a balanced GL journal (DR Cash 1000 / CR Deposits payable
-- 2120), mirroring the Fase 1 settle payout in reverse. The funding legs
-- need their own linkage columns (the settle columns stay untouched), and
-- the funding event needs its own deposit_transaction type.
ALTER TABLE deposit_account
    ADD COLUMN IF NOT EXISTS fund_journal_id BIGINT NULL AFTER gl_journal_id,
    ADD COLUMN IF NOT EXISTS fund_gl_journal_id INT NULL AFTER fund_journal_id;
CREATE INDEX IF NOT EXISTS idx_deposit_fund_journal ON deposit_account (fund_journal_id);
CREATE INDEX IF NOT EXISTS idx_deposit_fund_gl ON deposit_account (fund_gl_journal_id);
ALTER TABLE deposit_account
    ADD CONSTRAINT fk_deposit_fund_journal FOREIGN KEY (fund_journal_id) REFERENCES journal_entries (journal_id),
    ADD CONSTRAINT fk_deposit_fund_gl FOREIGN KEY (fund_gl_journal_id) REFERENCES gl_journal (id);

ALTER TABLE deposit_transaction MODIFY COLUMN txn_type
    ENUM('INTEREST_POSTED','PRINCIPAL_PAYOUT','SETTLE','PRINCIPAL_FUNDED') NOT NULL;
