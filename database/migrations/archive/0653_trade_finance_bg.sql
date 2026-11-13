-- PR-201: Trade Finance — Bank Guarantee domain.
-- Extends bank_guarantee with customer/currency/expiry and adds bg_claim.

ALTER TABLE bank_guarantee
    ADD COLUMN IF NOT EXISTS applicant_customer_ref VARCHAR(40) NULL AFTER guarantee_ref,
    ADD COLUMN IF NOT EXISTS currency CHAR(3) NOT NULL DEFAULT 'IDR' AFTER guarantee_type,
    ADD COLUMN IF NOT EXISTS expiry_date DATE NULL AFTER guarantee_amount,
    ADD COLUMN IF NOT EXISTS gl_journal_id INT NULL AFTER close_reason;

ALTER TABLE bank_guarantee
    MODIFY COLUMN status ENUM(
        'OPEN','ACTIVE','DELETED',
        'DRAFT','SUBMITTED','APPROVED','ISSUED','CLAIMED','SETTLED','CLOSED','REJECTED','EXPIRED'
    ) NOT NULL DEFAULT 'DRAFT';

CREATE INDEX IF NOT EXISTS idx_bank_guarantee_customer ON bank_guarantee (applicant_customer_ref, status);
CREATE INDEX IF NOT EXISTS idx_bank_guarantee_expiry ON bank_guarantee (expiry_date, status);

CREATE TABLE IF NOT EXISTS bg_claim (
    claim_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    guarantee_id BIGINT NOT NULL,
    claim_ref VARCHAR(40) NOT NULL,
    amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    received_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status ENUM('RECEIVED','APPROVED','REJECTED','SETTLED') NOT NULL DEFAULT 'RECEIVED',
    settled_at DATETIME NULL,
    gl_journal_id INT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bg_claim_guarantee FOREIGN KEY (guarantee_id)
        REFERENCES bank_guarantee (id) ON DELETE CASCADE,
    UNIQUE KEY uq_bg_claim_ref (claim_ref),
    INDEX idx_bg_claim_status (guarantee_id, status),
    CHECK (amount > 0)
) ENGINE=InnoDB;
