-- Lending Fase 5: idempotency key for LOAN_DISBURSE.
-- Mirrors loan_repay_request (0678): a client-supplied key (P5) claims a
-- PENDING request row and owns it; a repeated key replays the stored DONE
-- outcome (or conflicts on a different amount) instead of posting again; a
-- key whose owner is still working is refused (DISBURSE_IN_PROGRESS) so two
-- owners never disburse twice; a PENDING row older than 5 minutes is taken
-- over (owner crashed). Refusals before posting delete the owned PENDING
-- row so the key stays usable.
CREATE TABLE IF NOT EXISTS loan_disburse_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    loan_id BIGINT NOT NULL,
    idempotency_key VARCHAR(64) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','DONE') NOT NULL DEFAULT 'PENDING',
    gl_journal_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_disburse_idem (loan_id, idempotency_key),
    INDEX idx_disburse_req_loan (loan_id),
    CONSTRAINT fk_disburse_req_loan FOREIGN KEY (loan_id)
        REFERENCES loan_application (id) ON DELETE CASCADE
) ENGINE=InnoDB;
