-- Collections: idempotency keys for COL_PAY. Mirrors the loan/card
-- request tables: a client-supplied key (P5) claims a PENDING request
-- row and owns it; a repeat replays the stored DONE outcome (or conflicts
-- on a different amount) instead of recording another payment; a key
-- whose owner is still working is refused (PAY_IN_PROGRESS) so two owners
-- never double-count; a PENDING row older than 5 minutes is taken over
-- (owner crashed). Refusals before recording delete the owned PENDING row
-- so the key stays usable.
CREATE TABLE IF NOT EXISTS collection_pay_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NOT NULL,
    idempotency_key VARCHAR(64) NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','DONE') NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_pay_idem (case_id, idempotency_key),
    INDEX idx_pay_req_case (case_id),
    CONSTRAINT fk_pay_req_case FOREIGN KEY (case_id)
        REFERENCES collection_case (id) ON DELETE CASCADE
) ENGINE=InnoDB;
