-- PR-401: Tax Withholding — rule engine (extend tax_management) + entry ledger.
-- Keeps tax_management as the single rule table; legacy generic
-- tax_withholding / tax_item are left untouched (deprecation in PR-403).

ALTER TABLE tax_management
    ADD COLUMN IF NOT EXISTS rule_code VARCHAR(40) NULL AFTER tax_ref,
    ADD COLUMN IF NOT EXISTS rate_pct DECIMAL(9,4) NOT NULL DEFAULT 0 AFTER max_tax,
    ADD COLUMN IF NOT EXISTS fixed_amount DECIMAL(18,4) NOT NULL DEFAULT 0 AFTER rate_pct,
    ADD COLUMN IF NOT EXISTS threshold_amount DECIMAL(18,4) NOT NULL DEFAULT 0 AFTER fixed_amount,
    ADD COLUMN IF NOT EXISTS currency CHAR(3) NOT NULL DEFAULT 'IDR' AFTER threshold_amount,
    ADD COLUMN IF NOT EXISTS gl_account_code VARCHAR(20) NULL AFTER currency,
    ADD COLUMN IF NOT EXISTS effective_from DATE NULL AFTER gl_account_code,
    ADD COLUMN IF NOT EXISTS effective_to DATE NULL AFTER effective_from,
    ADD COLUMN IF NOT EXISTS enabled BOOLEAN NOT NULL DEFAULT TRUE AFTER effective_to;

CREATE UNIQUE INDEX IF NOT EXISTS uq_tax_management_rule ON tax_management (rule_code);

CREATE TABLE IF NOT EXISTS tax_withholding_entry (
    entry_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    source_type ENUM('DEPOSIT_INTEREST','FEE','PAYMENT','PAYROLL','OTHER') NOT NULL DEFAULT 'OTHER',
    source_ref VARCHAR(50) NOT NULL,
    customer_ref VARCHAR(40) NULL,
    base_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'IDR',
    rule_id BIGINT NULL,
    status ENUM('CALCULATED','POSTED','REVERSED') NOT NULL DEFAULT 'CALCULATED',
    gl_journal_id INT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reversed_at DATETIME NULL,
    reversal_reason VARCHAR(255) NULL,
    CONSTRAINT fk_tax_entry_rule FOREIGN KEY (rule_id)
        REFERENCES tax_management (id) ON DELETE SET NULL,
    UNIQUE KEY uq_tax_entry_source (source_type, source_ref),
    INDEX idx_tax_entry_status (status, source_type),
    INDEX idx_tax_entry_customer (customer_ref, status),
    CHECK (base_amount >= 0),
    CHECK (tax_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tax_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    entry_id BIGINT NULL,
    rule_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_tax_audit_actor (actor_email, created_at),
    INDEX idx_tax_audit_entry (entry_id, created_at),
    INDEX idx_tax_audit_rule (rule_id, created_at)
) ENGINE=InnoDB;
