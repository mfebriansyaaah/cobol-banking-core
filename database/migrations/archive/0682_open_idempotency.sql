-- Lending Fase 7 (kontrak v2): idempotency key for DEP_OPEN.
-- OPEN generates its own deposit id, so the key (P7, global per keyspace)
-- is claimed BEFORE the row exists. First call inserts a PENDING request
-- row carrying the full business tuple and owns it; a repeated key replays
-- the stored DONE outcome (deposit id) or conflicts when any of email,
-- principal, currency, term, or rate differs, instead of funding a second
-- deposit. A key whose owner is still working is refused
-- (OPEN_IN_PROGRESS) so two owners never fund twice. A PENDING row older
-- than 5 minutes is taken over: the stored deposit (if linked) is adopted
-- and funded instead of inserting a duplicate. Refusals before posting
-- delete the owned PENDING row so the key stays usable.
CREATE TABLE IF NOT EXISTS deposit_open_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    idempotency_key VARCHAR(64) NOT NULL,
    customer_email VARCHAR(100) NOT NULL,
    principal DECIMAL(18,4) NOT NULL,
    currency CHAR(3) NOT NULL,
    term_months INT NOT NULL,
    interest_rate VARCHAR(20) NOT NULL,
    status ENUM('PENDING','DONE') NOT NULL DEFAULT 'PENDING',
    deposit_id BIGINT NULL,
    fund_gl_journal_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_open_idem (idempotency_key),
    INDEX idx_open_req_deposit (deposit_id),
    CONSTRAINT fk_open_req_deposit FOREIGN KEY (deposit_id)
        REFERENCES deposit_account (id) ON DELETE CASCADE
) ENGINE=InnoDB;
