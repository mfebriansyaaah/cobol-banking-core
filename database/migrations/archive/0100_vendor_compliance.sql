-- Phase 2 slice: vendor compliance tracking.

CREATE TABLE IF NOT EXISTS vendor_compliance (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    vendor_code VARCHAR(64) NOT NULL,
    status ENUM('PENDING','APPROVED') NOT NULL DEFAULT 'PENDING',
    assessed_by VARCHAR(100) NOT NULL,
    assessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_by VARCHAR(100) NULL,
    approved_at DATETIME NULL,
    INDEX idx_vendor_compliance_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vendor_compliance_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    assessment_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_vendor_compliance_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
