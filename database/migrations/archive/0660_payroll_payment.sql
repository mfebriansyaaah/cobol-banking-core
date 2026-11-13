-- PR-601: Payroll — payment + audit.

CREATE TABLE IF NOT EXISTS payroll_payment (
    payment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    batch_id BIGINT NOT NULL,
    employee_id BIGINT NOT NULL,
    payment_clearing_ref VARCHAR(40) NULL,
    amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('PENDING','POSTED','PAID','FAILED') NOT NULL DEFAULT 'PENDING',
    posted_at DATETIME NULL,
    paid_at DATETIME NULL,
    error_code VARCHAR(100) NULL,
    error_detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payroll_pay_batch FOREIGN KEY (batch_id)
        REFERENCES payroll_processing (id) ON DELETE CASCADE,
    CONSTRAINT fk_payroll_pay_employee FOREIGN KEY (employee_id)
        REFERENCES payroll_employee (employee_id) ON DELETE CASCADE,
    INDEX idx_payroll_payment_batch (batch_id, status),
    CHECK (amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payroll_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    batch_id BIGINT NULL,
    employee_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_payroll_audit_actor (actor_email, created_at),
    INDEX idx_payroll_audit_batch (batch_id, created_at)
) ENGINE=InnoDB;
