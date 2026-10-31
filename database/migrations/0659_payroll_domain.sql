-- PR-601: Payroll — batch header as payroll_batch shape + employee/item.
-- Extends payroll_processing in place (kept name for compat); legacy generic
-- rows keep working. New child tables carry the domain model.

ALTER TABLE payroll_processing
    ADD COLUMN IF NOT EXISTS company_customer_ref VARCHAR(40) NULL AFTER payroll_ref,
    ADD COLUMN IF NOT EXISTS period_start DATE NULL AFTER payroll_type,
    ADD COLUMN IF NOT EXISTS period_end DATE NULL AFTER period_start,
    ADD COLUMN IF NOT EXISTS currency CHAR(3) NOT NULL DEFAULT 'IDR' AFTER period_end,
    ADD COLUMN IF NOT EXISTS source_account_id INT NULL AFTER currency,
    ADD COLUMN IF NOT EXISTS total_gross DECIMAL(18,4) NOT NULL DEFAULT 0 AFTER source_account_id,
    ADD COLUMN IF NOT EXISTS total_tax DECIMAL(18,4) NOT NULL DEFAULT 0 AFTER total_gross,
    ADD COLUMN IF NOT EXISTS total_net DECIMAL(18,4) NOT NULL DEFAULT 0 AFTER total_tax,
    ADD COLUMN IF NOT EXISTS approved_by VARCHAR(100) NULL AFTER completed_at,
    ADD COLUMN IF NOT EXISTS approved_at DATETIME NULL AFTER approved_by,
    ADD COLUMN IF NOT EXISTS paid_at DATETIME NULL AFTER approved_at;

ALTER TABLE payroll_processing
    MODIFY COLUMN status ENUM('OPEN','ACTIVE','COMPLETED','DELETED','DRAFT','VALIDATED','APPROVED','PROCESSING','PAID','FAILED','CLOSED')
    NOT NULL DEFAULT 'DRAFT';

CREATE INDEX IF NOT EXISTS idx_payroll_company ON payroll_processing (company_customer_ref, status);

CREATE TABLE IF NOT EXISTS payroll_employee (
    employee_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    batch_id BIGINT NOT NULL,
    employee_ref VARCHAR(40) NOT NULL,
    employee_name VARCHAR(100) NOT NULL,
    employee_account_id INT NULL,
    gross_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    deduction_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    net_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('PENDING','VALID','PAID','FAILED') NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payroll_emp_batch FOREIGN KEY (batch_id)
        REFERENCES payroll_processing (id) ON DELETE CASCADE,
    UNIQUE KEY uq_payroll_employee (batch_id, employee_ref),
    INDEX idx_payroll_employee_batch (batch_id, status),
    CHECK (gross_amount >= 0),
    CHECK (tax_amount >= 0),
    CHECK (deduction_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payroll_item (
    item_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    batch_id BIGINT NOT NULL,
    employee_id BIGINT NOT NULL,
    item_type ENUM('SALARY','BONUS','ALLOWANCE','DEDUCTION','TAX') NOT NULL DEFAULT 'SALARY',
    amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    gl_account_code VARCHAR(20) NULL,
    detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payroll_item_batch FOREIGN KEY (batch_id)
        REFERENCES payroll_processing (id) ON DELETE CASCADE,
    CONSTRAINT fk_payroll_item_employee FOREIGN KEY (employee_id)
        REFERENCES payroll_employee (employee_id) ON DELETE CASCADE,
    INDEX idx_payroll_item_batch (batch_id, item_type),
    CHECK (amount >= 0)
) ENGINE=InnoDB;
