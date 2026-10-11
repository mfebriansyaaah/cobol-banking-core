-- Migration 0001: pending_transactions FKs -> ON DELETE CASCADE.
-- Rationale: a populated pending_transactions table used to block suites (and
-- any operation) that delete users, because the FK to users(email) had no
-- ON DELETE behavior. Transfer intents are owned by the user, so cascade.
-- Applied to the development database on 2026-10-11.

ALTER TABLE pending_transactions
    DROP FOREIGN KEY fk_pending_from;
ALTER TABLE pending_transactions
    ADD CONSTRAINT fk_pending_from FOREIGN KEY (from_email) REFERENCES users(email) ON DELETE CASCADE;

ALTER TABLE pending_transactions
    DROP FOREIGN KEY fk_pending_to;
ALTER TABLE pending_transactions
    ADD CONSTRAINT fk_pending_to FOREIGN KEY (to_email) REFERENCES users(email) ON DELETE CASCADE;
