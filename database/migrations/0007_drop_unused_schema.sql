-- Migration 0007: drop unused schema elements.
-- These are leftovers with no reader or writer in the binary:
--   users.balance / users.verification_code  (accounts.balance and
--     verification_logs are authoritative)
--   exchange_rates                           (no FX path exists yet; re-add
--     with the FX feature)
--   audit_trail.old_value / new_value / ip_address (never populated)
ALTER TABLE users DROP COLUMN balance;
ALTER TABLE users DROP COLUMN verification_code;
ALTER TABLE audit_trail DROP COLUMN old_value;
ALTER TABLE audit_trail DROP COLUMN new_value;
ALTER TABLE audit_trail DROP COLUMN ip_address;
DROP TABLE IF EXISTS exchange_rates;
