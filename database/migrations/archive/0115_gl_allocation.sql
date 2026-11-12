-- D8 finance: GL allocation.

CREATE TABLE IF NOT EXISTS gl_allocation (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alloc_ref VARCHAR(40) NOT NULL,
    source_ref VARCHAR(100) NOT NULL,
    target_gl VARCHAR(20) NOT NULL,
    allocated_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    settled_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ALLOCATED','SETTLED','CLOSED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    allocated_at DATETIME NULL,
    settled_at DATETIME NULL,
    closed_at DATETIME NULL,
    closure_reason VARCHAR(255) NULL,
    UNIQUE KEY uq_gl_allocation_ref (alloc_ref),
    INDEX idx_gl_allocation_status (status, target_gl)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS gl_allocation_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    alloc_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gl_allocation_audit_actor (actor_email, created_at),
    INDEX idx_gl_allocation_audit_case (alloc_id, created_at)
) ENGINE=InnoDB;
