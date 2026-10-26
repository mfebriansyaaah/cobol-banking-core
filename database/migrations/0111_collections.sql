-- D4 collections: delinquency cases, contact history, promises, recovery and audit.

CREATE TABLE IF NOT EXISTS collection_case (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_ref VARCHAR(40) NOT NULL,
    loan_id BIGINT NOT NULL,
    installment_id BIGINT NULL,
    customer_email VARCHAR(100) NOT NULL,
    currency CHAR(3) NOT NULL,
    overdue_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    recovered_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    oldest_due_date DATE NULL,
    priority ENUM('LOW','NORMAL','HIGH','CRITICAL') NOT NULL DEFAULT 'NORMAL',
    status ENUM('OPEN','PROMISE','ESCALATED','CLOSED','CANCELLED') NOT NULL DEFAULT 'OPEN',
    assigned_to VARCHAR(100) NULL,
    promise_date DATE NULL,
    promise_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    escalation_level TINYINT NOT NULL DEFAULT 0,
    resolution VARCHAR(255) NULL,
    opened_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    closed_at DATETIME NULL,
    UNIQUE KEY uq_collection_case_ref (case_ref),
    INDEX idx_collection_case_status (status, priority),
    INDEX idx_collection_case_assignee (assigned_to, status),
    INDEX idx_collection_case_loan (loan_id),
    CONSTRAINT fk_collection_case_loan FOREIGN KEY (loan_id)
        REFERENCES loan_application (id) ON DELETE CASCADE,
    CONSTRAINT fk_collection_case_installment FOREIGN KEY (installment_id)
        REFERENCES loan_installment (id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS collection_activity (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NOT NULL,
    activity_type ENUM('CONTACT','PROMISE','PAYMENT','ESCALATION','ASSIGNMENT','NOTE','STATUS')
        NOT NULL,
    channel ENUM('CALL','EMAIL','SMS','LETTER','IN_PERSON','SYSTEM') NULL,
    note VARCHAR(255) NULL,
    amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    actor_email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_collection_activity_case (case_id, created_at),
    CONSTRAINT fk_collection_activity_case FOREIGN KEY (case_id)
        REFERENCES collection_case (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS collection_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    case_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_collection_audit_actor (actor_email, created_at),
    INDEX idx_collection_audit_case (case_id, created_at)
) ENGINE=InnoDB;
