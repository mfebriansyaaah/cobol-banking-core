-- D7 compliance: KYC periodic reviews.

CREATE TABLE IF NOT EXISTS kyc_periodic (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    review_ref VARCHAR(40) NOT NULL,
    customer_email VARCHAR(100) NOT NULL,
    risk_score VARCHAR(20) NULL,
    amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency CHAR(3) NULL,
    status ENUM('OPEN','PENDING','APPROVED','REJECTED','CLOSED') NOT NULL DEFAULT 'OPEN',
    submitted_count INT NOT NULL DEFAULT 0,
    approved_count INT NOT NULL DEFAULT 0,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    submitted_at DATETIME NULL,
    approved_at DATETIME NULL,
    closed_at DATETIME NULL,
    closure_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_kyc_periodic_ref (review_ref),
    INDEX idx_kyc_periodic_email (customer_email, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS kyc_periodic_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    review_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_kyc_periodic_audit_actor (actor_email, created_at),
    INDEX idx_kyc_periodic_audit_case (review_id, created_at)
) ENGINE=InnoDB;
