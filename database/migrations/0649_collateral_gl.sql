-- PR-103b / PR-104: Collateral GL linkage + deprecation prep.
-- Adds gl_journal_id references and GL accounts for collateral flows.
-- Does NOT drop legacy generic tables (collateral_mgmt, collateral_repossession,
-- collateralized); those are deprecated in docs and removed in a later cycle.

ALTER TABLE collateral
    ADD COLUMN IF NOT EXISTS gl_journal_id INT NULL AFTER latest_valuation_id;

ALTER TABLE collateral_valuation
    ADD COLUMN IF NOT EXISTS gl_journal_id INT NULL AFTER created_by;

-- GL accounts for collateral lifecycle (idempotent seeds).
INSERT INTO gl_account (account_code, name, account_type, normal_side, parent_code, is_active)
VALUES
    ('1510', 'Repossessed Collateral', 'ASSET', 'DEBIT', NULL, TRUE),
    ('4210', 'Gain on Collateral Disposal', 'REVENUE', 'CREDIT', NULL, TRUE),
    ('5210', 'Loss on Collateral Disposal', 'EXPENSE', 'DEBIT', NULL, TRUE)
ON DUPLICATE KEY UPDATE name = VALUES(name), is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_collateral_gl ON collateral (gl_journal_id);
