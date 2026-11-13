-- Migration 0033: maker-checker (dual control) framework.
-- 1) dual_control_operations: the bank-owned designation list. An operation
--    present here cannot run directly: the privileged action refuses with
--    DUAL_CONTROL_REQUIRED and the change must travel the request path.
--    Empty by default, so nothing changes until the accountable owner
--    designates operations (Gate 0).
-- 2) maker_requests: one row per proposed privileged change. PENDING rows
--    await a checker; APPROVE executes the effect in the same transaction
--    (no dangling approvals); REJECTED rows are terminal. Checker and maker
--    must differ (no self-approval), enforced in COBOL.
CREATE TABLE IF NOT EXISTS dual_control_operations (
    operation VARCHAR(50) PRIMARY KEY
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS maker_requests (
    request_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    operation VARCHAR(50) NOT NULL,
    target_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255) NULL,
    maker_email VARCHAR(100) NOT NULL,
    checker_email VARCHAR(100) NULL,
    state ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_at TIMESTAMP NULL,
    CONSTRAINT fk_maker_request_op FOREIGN KEY (operation)
        REFERENCES dual_control_operations(operation),
    KEY idx_maker_state (state)
) ENGINE=InnoDB;
