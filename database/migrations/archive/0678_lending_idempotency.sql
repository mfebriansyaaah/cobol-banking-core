-- Lending Fase 3: idempotency keys for LOAN_REPAY and DEP_SETTLE.
-- Mirrors payment_settle_request (0675): a client-supplied key (P5) claims
-- a PENDING request row and owns it; a repeated key replays the stored
-- DONE outcome (or conflicts on a different amount) instead of posting
-- again; a key whose owner is still working is refused so two owners never
-- post twice. A PENDING row older than 5 minutes is taken over (owner
-- crashed). Refusals before posting delete the owned PENDING row so the
-- key stays usable.
CREATE TABLE IF NOT EXISTS loan_repay_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    loan_id BIGINT NOT NULL,
    idempotency_key VARCHAR(64) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','DONE') NOT NULL DEFAULT 'PENDING',
    gl_journal_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_repay_idem (loan_id, idempotency_key),
    INDEX idx_repay_req_loan (loan_id),
    CONSTRAINT fk_repay_req_loan FOREIGN KEY (loan_id)
        REFERENCES loan_application (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS deposit_settle_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    deposit_id BIGINT NOT NULL,
    idempotency_key VARCHAR(64) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','DONE') NOT NULL DEFAULT 'PENDING',
    gl_journal_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_settle_idem (deposit_id, idempotency_key),
    INDEX idx_settle_req_deposit (deposit_id),
    CONSTRAINT fk_settle_req_deposit FOREIGN KEY (deposit_id)
        REFERENCES deposit_account (id) ON DELETE CASCADE
) ENGINE=InnoDB;
