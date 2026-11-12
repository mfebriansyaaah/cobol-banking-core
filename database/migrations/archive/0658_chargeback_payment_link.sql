-- PR-503: Chargeback — payment clearing link.
ALTER TABLE chargeback_case
    ADD COLUMN IF NOT EXISTS payment_clearing_ref VARCHAR(40) NULL AFTER resolution;
CREATE INDEX IF NOT EXISTS idx_chargeback_case_pmc ON chargeback_case (payment_clearing_ref);
