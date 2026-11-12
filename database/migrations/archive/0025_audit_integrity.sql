-- Migration 0025: audit-trail integrity.
-- 1) Indexes used by the LIST_AUDIT read path.
-- 2) Preserve audit evidence when a user is deleted: the FK on
--    audit_trail.user_id is ON DELETE CASCADE, so deleting a user would erase
--    their history. The trigger copies those rows into the append-only
--    audit_trail_archive *before* the cascade removes them, so the evidence
--    survives (only the live copy is cleaned up).
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_trail (action);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON audit_trail (actor_id);

DELIMITER //
CREATE TRIGGER IF NOT EXISTS trg_audit_snapshot_user_delete BEFORE DELETE ON users
FOR EACH ROW
BEGIN
    INSERT IGNORE INTO audit_trail_archive (audit_id, user_id, actor_id, action, entity_type, entity_id, detail, status, created_at)
    SELECT audit_id, user_id, actor_id, action, entity_type, entity_id, detail, status, created_at
    FROM audit_trail WHERE user_id = OLD.id;
END//
DELIMITER ;
