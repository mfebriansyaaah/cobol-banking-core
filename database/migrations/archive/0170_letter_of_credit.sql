CREATE TABLE IF NOT EXISTS letter_of_credit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    lc_ref VARCHAR(40) NOT NULL,
    applicant_name VARCHAR(100) NOT NULL,
    lc_type VARCHAR(20) NOT NULL,
    lc_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    drawn_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    issued_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_letter_of_credit_ref (lc_ref),
    INDEX idx_letter_of_credit_status (status, lc_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS letter_of_credit_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    letter_of_credit_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_LOC_audit_actor (actor_email, created_at),
    INDEX idx_LOC_audit_letter_of_credit (letter_of_credit_id, created_at)
) ENGINE=InnoDB;
