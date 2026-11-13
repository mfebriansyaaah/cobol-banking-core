-- Phase 1 Sprint 1 slice 17: audit drill-down queries and compliance export packages.

CREATE TABLE IF NOT EXISTS audit_drilldown_query (
    query_code VARCHAR(40) PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    filter_spec VARCHAR(255) NOT NULL,
    saved_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_drilldown_run (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    query_code VARCHAR(40) NOT NULL,
    row_count BIGINT NOT NULL DEFAULT 0,
    digest CHAR(64) NULL,
    executed_by VARCHAR(100) NOT NULL,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_adr_run_query (query_code, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_drilldown_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    query_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_adr_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compliance_export_package (
    package_code VARCHAR(40) PRIMARY KEY,
    framework ENUM('SOX','GDPR','PCI','AML') NOT NULL,
    title VARCHAR(120) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    status ENUM('DRAFT','SEALED','ATTESTED','REVOKED') NOT NULL DEFAULT 'DRAFT',
    checksum CHAR(64) NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sealed_at DATETIME NULL,
    attested_by VARCHAR(100) NULL,
    attested_at DATETIME NULL,
    revoke_reason VARCHAR(255) NULL,
    CHECK (period_end >= period_start)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compliance_export_item (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    package_code VARCHAR(40) NOT NULL,
    item_type ENUM('AUDIT_QUERY','EXPORT_ARCHIVE','REPORT_RUN') NOT NULL,
    ref_id VARCHAR(64) NOT NULL,
    included BOOLEAN NOT NULL DEFAULT TRUE,
    detail VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cex_item_package FOREIGN KEY (package_code)
        REFERENCES compliance_export_package(package_code) ON DELETE CASCADE,
    UNIQUE KEY uq_cex_item (package_code, item_type, ref_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compliance_export_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    package_code VARCHAR(40) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_cex_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
