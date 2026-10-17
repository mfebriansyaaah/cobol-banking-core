-- Migration 0029: restore the FX pair lookup index.
-- schema.sql always had idx_exchange_lookup(base_currency_id,
-- target_currency_id), but migration 0008 re-created the table without it
-- (after 0007 dropped it). Migrated databases converge back to the schema
-- baseline here; fresh installs already carry the index.
CREATE INDEX idx_exchange_lookup ON exchange_rates (base_currency_id, target_currency_id);
