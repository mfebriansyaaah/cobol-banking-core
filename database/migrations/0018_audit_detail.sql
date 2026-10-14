-- Migration 0018: free-form context on audit rows.
-- The TRANSFER row records "to:amount:currency" so the amount/target are on the
-- audit trail; the archive carries the same column.
ALTER TABLE audit_trail ADD COLUMN detail VARCHAR(255) NULL AFTER entity_id;
ALTER TABLE audit_trail_archive ADD COLUMN detail VARCHAR(255) NULL AFTER entity_id;
