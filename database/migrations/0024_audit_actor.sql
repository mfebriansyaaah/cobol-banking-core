-- Migration 0024: record the acting administrator on audit rows.
-- `user_id` is the subject of an action; `actor_id` is who performed it (NULL
-- means the actor was the subject, e.g. self-service). Admin-on-other actions
-- (SET_USER_STATUS, SESSIONS_REVOKED, REVOKE_USER_SESSION, ARCHIVE_AUDIT) now
-- set actor_id so the trail answers "who did it to whom". The archive keeps the
-- same column so archived rows preserve the attribution.
ALTER TABLE audit_trail ADD COLUMN actor_id INT NULL AFTER user_id;
ALTER TABLE audit_trail_archive ADD COLUMN actor_id INT NULL AFTER user_id;
