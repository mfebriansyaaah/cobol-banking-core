-- Migration 0028: the audit trail is append-only.
-- Like the ledger, audit rows must never be edited in place: a correction is a
-- new appended entry (with the same attribution). UPDATE is refused by a
-- trigger; DELETE is still allowed so the user-delete cascade can move rows
-- into audit_trail_archive via the existing snapshot trigger.
DELIMITER //
CREATE TRIGGER IF NOT EXISTS trg_audit_no_update BEFORE UPDATE ON audit_trail
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_trail is append-only (no UPDATE)';
END//
DELIMITER ;
