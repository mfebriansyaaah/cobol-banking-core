-- Lending Fase 6: interest expense posting at DEP_POST.
-- Posting moves accrued interest to posted (state only). Real accrual
-- accounting also recognizes the expense: DR Deposit interest expense /
-- CR Deposits payable, one balanced GL journal per POST batch, linked from
-- the deposit row. The later settle payout (DR 2120 / CR 1000, principal +
-- interest) then clears a liability that actually grew, instead of paying
-- interest the books never recognized.
INSERT IGNORE INTO gl_account (account_code, name, account_type, normal_side, is_active) VALUES
('5010', 'Deposit interest expense', 'EXPENSE', 'DEBIT', TRUE);

ALTER TABLE deposit_account
    ADD COLUMN IF NOT EXISTS post_gl_journal_id INT NULL AFTER fund_gl_journal_id;
CREATE INDEX IF NOT EXISTS idx_deposit_post_gl ON deposit_account (post_gl_journal_id);
ALTER TABLE deposit_account
    ADD CONSTRAINT fk_deposit_post_gl FOREIGN KEY (post_gl_journal_id) REFERENCES gl_journal (id);
