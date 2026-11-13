-- Lending Fase 8: outstanding ceiling for LOAN_REPAY.
-- Repayments were bounded only by the borrower's wallet: a loan could be
-- repaid many times over with no notion of debt outstanding. The
-- application now tracks lifetime repaid principal; the money transaction
-- advances it under a guarded increment (repaid_total + amount <=
-- principal) so any concurrent overpay is refused instead of printing
-- money the borrower never owed. Existing PAID rows are backfilled so the
-- guard is exact from day one.
ALTER TABLE loan_application
    ADD COLUMN IF NOT EXISTS repaid_total DECIMAL(18,4) NOT NULL DEFAULT 0 AFTER disbursed_at;
UPDATE loan_application a
    SET a.repaid_total = COALESCE(
        (SELECT SUM(r.amount) FROM loan_repayment r
          WHERE r.loan_id = a.id AND r.status = 'PAID'), 0);
