-- Migration 0003: allow users.email to change while related rows exist.
-- refresh_sessions (created on login) and pending_transactions reference
-- users(email) with ON DELETE CASCADE only, so an UPDATE of the email failed
-- with errno 1451. Add ON UPDATE CASCADE so CONFIRM_EMAIL_CHANGE works for a
-- logged-in user. Applied 2026-10-11.
ALTER TABLE refresh_sessions DROP FOREIGN KEY fk_refresh_user;
ALTER TABLE refresh_sessions ADD CONSTRAINT fk_refresh_user FOREIGN KEY (email) REFERENCES users(email) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE pending_transactions DROP FOREIGN KEY fk_pending_from;
ALTER TABLE pending_transactions ADD CONSTRAINT fk_pending_from FOREIGN KEY (from_email) REFERENCES users(email) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE pending_transactions DROP FOREIGN KEY fk_pending_to;
ALTER TABLE pending_transactions ADD CONSTRAINT fk_pending_to FOREIGN KEY (to_email) REFERENCES users(email) ON DELETE CASCADE ON UPDATE CASCADE;
