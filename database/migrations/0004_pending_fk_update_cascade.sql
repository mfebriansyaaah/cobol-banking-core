-- Migration 0004: restore ON UPDATE CASCADE on pending_transactions.
-- Migration 0001 was authored after 0003 but numbered lower; applying it to a
-- database that already had 0003 recreated the pending_transactions FKs with
-- ON DELETE CASCADE only, silently undoing 0003. Without ON UPDATE CASCADE a
-- user who has a pending transaction (e.g. any transfer) cannot change their
-- email: the UPDATE fails with errno 1451. Restore the cascade.
ALTER TABLE pending_transactions DROP FOREIGN KEY fk_pending_from;
ALTER TABLE pending_transactions ADD CONSTRAINT fk_pending_from FOREIGN KEY (from_email) REFERENCES users(email) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE pending_transactions DROP FOREIGN KEY fk_pending_to;
ALTER TABLE pending_transactions ADD CONSTRAINT fk_pending_to FOREIGN KEY (to_email) REFERENCES users(email) ON DELETE CASCADE ON UPDATE CASCADE;
