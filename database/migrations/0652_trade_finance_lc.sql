-- PR-201: Trade Finance — Letter of Credit domain.
-- Extends letter_of_credit with customer/currency/expiry/terms, broadens
-- status to the real lifecycle, and adds amendment/document/drawing/settlement.
-- Existing generic `documentary_credit`, `bankers_acceptance`, `export_finance`,
-- `import_finance`, `factoring` are left for deprecation in PR-205.

ALTER TABLE letter_of_credit
    ADD COLUMN IF NOT EXISTS applicant_customer_ref VARCHAR(40) NULL AFTER lc_ref,
    ADD COLUMN IF NOT EXISTS beneficiary_name VARCHAR(100) NULL AFTER applicant_name,
    ADD COLUMN IF NOT EXISTS beneficiary_bank VARCHAR(100) NULL AFTER beneficiary_name,
    ADD COLUMN IF NOT EXISTS currency CHAR(3) NOT NULL DEFAULT 'IDR' AFTER lc_type,
    ADD COLUMN IF NOT EXISTS expiry_date DATE NULL AFTER lc_amount,
    ADD COLUMN IF NOT EXISTS latest_shipment_date DATE NULL AFTER expiry_date,
    ADD COLUMN IF NOT EXISTS terms VARCHAR(500) NULL AFTER latest_shipment_date,
    ADD COLUMN IF NOT EXISTS gl_journal_id INT NULL AFTER close_reason;

ALTER TABLE letter_of_credit
    MODIFY COLUMN status ENUM(
        'OPEN','ACTIVE','DELETED',
        'DRAFT','SUBMITTED','APPROVED','ISSUED','AMENDED',
        'DRAWN','SETTLED','CLOSED','REJECTED','EXPIRED'
    ) NOT NULL DEFAULT 'DRAFT';

CREATE INDEX IF NOT EXISTS idx_letter_of_credit_customer ON letter_of_credit (applicant_customer_ref, status);
CREATE INDEX IF NOT EXISTS idx_letter_of_credit_expiry ON letter_of_credit (expiry_date, status);

CREATE TABLE IF NOT EXISTS lc_amendment (
    amendment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    lc_id BIGINT NOT NULL,
    amendment_no INT NOT NULL,
    amount_delta DECIMAL(18,4) NOT NULL DEFAULT 0,
    new_expiry_date DATE NULL,
    new_terms VARCHAR(500) NULL,
    status ENUM('DRAFT','APPROVED','REJECTED') NOT NULL DEFAULT 'DRAFT',
    approved_by VARCHAR(100) NULL,
    approved_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_lc_amendment_lc FOREIGN KEY (lc_id)
        REFERENCES letter_of_credit (id) ON DELETE CASCADE,
    UNIQUE KEY uq_lc_amendment_no (lc_id, amendment_no),
    INDEX idx_lc_amendment_status (lc_id, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS lc_document (
    document_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    lc_id BIGINT NOT NULL,
    doc_type VARCHAR(40) NOT NULL,
    doc_ref VARCHAR(80) NOT NULL,
    received_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status ENUM('RECEIVED','CHECKED','ACCEPTED','REJECTED') NOT NULL DEFAULT 'RECEIVED',
    discrepancy VARCHAR(255) NULL,
    file_ref VARCHAR(100) NULL,
    checked_by VARCHAR(100) NULL,
    checked_at DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_lc_document_lc FOREIGN KEY (lc_id)
        REFERENCES letter_of_credit (id) ON DELETE CASCADE,
    INDEX idx_lc_document_lc (lc_id, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS lc_drawing (
    drawing_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    lc_id BIGINT NOT NULL,
    drawing_no INT NOT NULL,
    amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'IDR',
    presented_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    accepted_at DATETIME NULL,
    due_date DATE NULL,
    status ENUM('PRESENTED','ACCEPTED','REJECTED','SETTLED') NOT NULL DEFAULT 'PRESENTED',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_lc_drawing_lc FOREIGN KEY (lc_id)
        REFERENCES letter_of_credit (id) ON DELETE CASCADE,
    UNIQUE KEY uq_lc_drawing_no (lc_id, drawing_no),
    INDEX idx_lc_drawing_status (lc_id, status),
    CHECK (amount > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS lc_settlement (
    settlement_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    drawing_id BIGINT NOT NULL,
    payment_clearing_ref VARCHAR(40) NULL,
    settled_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    fx_rate DECIMAL(18,8) NULL,
    gl_journal_id INT NULL,
    settled_at DATETIME NULL,
    status ENUM('PENDING','SETTLED','FAILED') NOT NULL DEFAULT 'PENDING',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_lc_settlement_drawing FOREIGN KEY (drawing_id)
        REFERENCES lc_drawing (drawing_id) ON DELETE CASCADE,
    INDEX idx_lc_settlement_status (drawing_id, status),
    CHECK (settled_amount >= 0)
) ENGINE=InnoDB;
