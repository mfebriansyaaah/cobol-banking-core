-- Migration 0036: customer dispute/ticket lifecycle (Gate 2, PRD 4.E).
-- dispute_cases: one row per customer complaint, optionally linked to a
-- transaction reference. Lifecycle OPEN -> ACKNOWLEDGED -> RESOLVED, with
-- REJECTED as the terminal refusal from OPEN or ACKNOWLEDGED. The admin who
-- acknowledges owns the case (assigned_to); due_date is set by that admin at
-- acknowledge time (no hardcoded SLA — the deadline is human policy, and the
-- list view computes an overdue flag from it). Resolution text is stored on
-- the terminal transition; every transition is audited by the COBOL actions.
-- dispute_messages: append-only case history. Immutability is enforced in
-- the database itself (BEFORE UPDATE/DELETE triggers abort), the same
-- mechanism the ledger and audit trail use; the COBOL layer only INSERTs.
CREATE TABLE IF NOT EXISTS dispute_cases (
    case_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    txn_ref VARCHAR(50) NULL,
    subject VARCHAR(100) NOT NULL,
    detail VARCHAR(100) NOT NULL,
    state ENUM('OPEN','ACKNOWLEDGED','RESOLVED','REJECTED') NOT NULL DEFAULT 'OPEN',
    assigned_to INT NULL,
    due_date DATE NULL,
    resolution VARCHAR(100) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    decided_at TIMESTAMP NULL,
    CONSTRAINT fk_dispute_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_dispute_assignee FOREIGN KEY (assigned_to)
        REFERENCES users(id) ON DELETE SET NULL,
    KEY idx_dispute_user_state (user_id, state)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dispute_messages (
    msg_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NOT NULL,
    author_id INT NOT NULL,
    body VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_msg_case FOREIGN KEY (case_id)
        REFERENCES dispute_cases(case_id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_author FOREIGN KEY (author_id)
        REFERENCES users(id) ON DELETE CASCADE,
    KEY idx_msg_case (case_id, msg_id)
) ENGINE=InnoDB;

DELIMITER //
CREATE TRIGGER IF NOT EXISTS trg_dispute_msg_no_update BEFORE UPDATE ON dispute_messages
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'dispute_messages is append-only (no UPDATE)';
END//

CREATE TRIGGER IF NOT EXISTS trg_dispute_msg_no_delete BEFORE DELETE ON dispute_messages
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'dispute_messages is append-only (no DELETE)';
END//
DELIMITER ;
