-- Phase 2 slice: loan amortization schedule.

CREATE TABLE IF NOT EXISTS loan_schedule (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    loan_id BIGINT NOT NULL,
    term_months INT NOT NULL,
    interest_rate DECIMAL(9,4) NOT NULL DEFAULT 0,
    start_date DATE NOT NULL,
    status ENUM('DRAFT','ACTIVE','ON_HOLD','CLOSED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
    version INT NOT NULL DEFAULT 1,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_loan_schedule_loan FOREIGN KEY (loan_id)
        REFERENCES loan_application(id) ON DELETE CASCADE,
    CHECK (term_months BETWEEN 1 AND 360)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loan_installment (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    schedule_id BIGINT NOT NULL,
    seq INT NOT NULL,
    due_date DATE NOT NULL,
    principal_due DECIMAL(18,4) NOT NULL,
    interest_due DECIMAL(18,4) NOT NULL,
    total_due DECIMAL(18,4) NOT NULL,
    status ENUM('PENDING','DUE','PAID','PARTIAL','WAIVED') NOT NULL DEFAULT 'PENDING',
    paid_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    paid_at DATETIME NULL,
    CONSTRAINT fk_loan_installment_schedule FOREIGN KEY (schedule_id)
        REFERENCES loan_schedule(id) ON DELETE CASCADE,
    UNIQUE KEY uq_loan_installment_seq (schedule_id, seq)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loan_schedule_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    schedule_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_loan_schedule_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
