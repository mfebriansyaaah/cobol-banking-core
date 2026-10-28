CREATE TABLE IF NOT EXISTS supply_chain_finance (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    scf_ref VARCHAR(40) NOT NULL,
    supplier_name VARCHAR(100) NOT NULL,
    scf_type VARCHAR(20) NOT NULL,
    facility_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    utilized_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','CLOSED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    closed_at DATETIME NULL,
    close_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_supply_chain_finance_ref (scf_ref),
    INDEX idx_supply_chain_finance_status (status, scf_type)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS supply_chain_finance_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    supply_chain_finance_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_SCF_audit_actor (actor_email, created_at),
    INDEX idx_SCF_audit_supply_chain_finance (supply_chain_finance_id, created_at)
) ENGINE=InnoDB;
