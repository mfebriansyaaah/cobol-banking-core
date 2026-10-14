-- Migration 0017: snapshot the FX rate applied to a transfer on the ledger.
-- The CREDIT row of a cross-currency transfer records the rate used; same
-- currency rows record 1. NULL means "not applicable" (pre-feature rows).
ALTER TABLE ledger ADD COLUMN exchange_rate DECIMAL(18, 6) NULL AFTER description;
