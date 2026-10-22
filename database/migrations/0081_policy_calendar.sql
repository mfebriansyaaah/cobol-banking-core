-- Phase 1 Sprint 1 slice 26: policy attestations and regulatory calendar.

CREATE TABLE IF NOT EXISTS policy_attestation (
    attestation_code VARCHAR(40) PRIMARY KEY,
    policy_name VARCHAR(120) NOT NULL,
    owner_email VARCHAR(100) NOT NULL,
    status ENUM('PENDING','ATTESTED','EXPIRED') NOT NULL DEFAULT 'PENDING',
    due_date DATE NULL,
    attested_at DATETIME NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS policy_attestation_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    attestation_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_policy_attestation_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS regulatory_calendar (
    event_code VARCHAR(40) PRIMARY KEY,
    title VARCHAR(120) NOT NULL,
    regulator VARCHAR(20) NOT NULL,
    due_date DATE NOT NULL,
    status ENUM('OPEN','DONE','CANCELLED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS regulatory_calendar_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    event_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_regulatory_calendar_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
