-- Lending Fase 4: close refunds.
-- DEP_CLOSE on a funded (ACTIVE/MATURED) deposit refunds the principal
-- (posted interest is forfeited) instead of stranding it in the pool:
-- without this, every close-without-settle since Fase 2 locks customer
-- money. Unfunded (PENDING) deposits close money-neutral. The refund is a
-- real posting (customer credit / DEPOSIT_POOL debit + GL DR 2120 / CR 1000)
-- linked through the terminal journal columns, plus a PRINCIPAL_REFUNDED
-- transaction row. A client-supplied key (P5) makes the refund idempotent,
-- mirroring deposit_settle_request.
ALTER TABLE deposit_transaction MODIFY COLUMN txn_type
    ENUM('INTEREST_POSTED','PRINCIPAL_PAYOUT','SETTLE','PRINCIPAL_FUNDED','PRINCIPAL_REFUNDED') NOT NULL;

CREATE TABLE IF NOT EXISTS deposit_close_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    deposit_id BIGINT NOT NULL,
    idempotency_key VARCHAR(64) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','DONE') NOT NULL DEFAULT 'PENDING',
    gl_journal_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_close_idem (deposit_id, idempotency_key),
    INDEX idx_close_req_deposit (deposit_id),
    CONSTRAINT fk_close_req_deposit FOREIGN KEY (deposit_id)
        REFERENCES deposit_account (id) ON DELETE CASCADE
) ENGINE=InnoDB;
