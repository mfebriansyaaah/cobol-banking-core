-- Migration 0026: link ledger rows to the transfer's sender.
-- A txn_ref (the client idempotency key) is unique per sender, not globally, so
-- a shared reference could make a reversal target the wrong transfer. Store the
-- sender on both ledger rows so DEBIT/CREDIT pair unambiguously, and key
-- reversals per (orig_ref, from_email). Legacy rows have NULL/'' sender.
ALTER TABLE ledger ADD COLUMN from_email VARCHAR(100) NULL, ADD INDEX idx_ledger_ref_sender (txn_ref, from_email);
ALTER TABLE transfer_reversals ADD COLUMN from_email VARCHAR(100) NOT NULL DEFAULT '';
ALTER TABLE transfer_reversals DROP PRIMARY KEY, ADD PRIMARY KEY (orig_ref, from_email);
