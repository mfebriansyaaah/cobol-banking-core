-- Migration 0040: one active control account per currency (audit finding).
-- Bank-owned FX_PNL and FEE_INCOME accounts are resolved by
-- (currency_id, account_type, status='ACTIVE') with LIMIT 1, so two
-- ACTIVE rows for the same pair would post to a nondeterministic account.
-- The generated control_slot is non-NULL exactly for rows matching that
-- lookup predicate, and its UNIQUE key allows at most one such row per
-- (currency, account_type); every other row maps to NULL (unconstrained).
-- A transfer with a missing or duplicated control account keeps failing
-- closed in COBOL (DB_ERROR); this migration only makes "duplicated"
-- impossible to create. It aborts loudly if duplicates already exist.
ALTER TABLE accounts ADD COLUMN control_slot VARCHAR(32) GENERATED ALWAYS AS
  (CASE WHEN status = 'ACTIVE' AND account_type IN ('FX_PNL','FEE_INCOME')
        THEN CONCAT(currency_id, '/', account_type) ELSE NULL END) STORED,
  ADD UNIQUE KEY uniq_active_control_acct (control_slot);
