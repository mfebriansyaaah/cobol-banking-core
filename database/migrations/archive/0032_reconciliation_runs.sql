-- Migration 0032: recorded reconciliation runs and exception workflow.
-- 1) reconciliation_runs: one immutable row per completed run (operator or
--    scheduled). The core computes the outcome first and inserts the final
--    row, so results are append-only by construction; a trigger refuses
--    UPDATE so a recorded result can never be edited.
-- 2) reconciliation_findings: one row per mismatched account per run, with
--    an ownership lifecycle (OPEN -> ACKNOWLEDGED -> RESOLVED) enforced in
--    COBOL and audited. Resolved findings keep their run link: evidence
--    survives resolution.
CREATE TABLE IF NOT EXISTS reconciliation_runs (
    run_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    trigger_src ENUM('MANUAL','SCHEDULED') NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    status ENUM('CLEAN','MISMATCH') NOT NULL,
    mismatch_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_recon_created (created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reconciliation_findings (
    finding_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    run_id BIGINT NOT NULL,
    account_id INT NOT NULL,
    balance DECIMAL(18, 4) NOT NULL,
    ledger_sum DECIMAL(18, 4) NOT NULL,
    status ENUM('OPEN','ACKNOWLEDGED','RESOLVED') NOT NULL DEFAULT 'OPEN',
    owner_email VARCHAR(100) NULL,
    resolution_note VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    CONSTRAINT fk_finding_run FOREIGN KEY (run_id)
        REFERENCES reconciliation_runs(run_id),
    CONSTRAINT fk_finding_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id) ON DELETE CASCADE,
    KEY idx_finding_status (status)
) ENGINE=InnoDB;

DELIMITER //
CREATE TRIGGER IF NOT EXISTS trg_recon_run_no_update BEFORE UPDATE ON reconciliation_runs
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'reconciliation runs are immutable';
END//
DELIMITER ;
