CREATE TABLE IF NOT EXISTS `document` (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    doc_ref VARCHAR(40) NOT NULL,
    doc_name VARCHAR(100) NOT NULL,
    doc_type VARCHAR(20) NOT NULL,
    file_size DECIMAL(18,4) NOT NULL DEFAULT 0,
    file_version DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','ARCHIVED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    verified_at DATETIME NULL,
    archived_at DATETIME NULL,
    archive_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_document_ref (doc_ref),
    INDEX idx_document_status (status, doc_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `document_audit` (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    document_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_document_audit_actor (actor_email, created_at),
    INDEX idx_document_audit_document (document_id, created_at)
) ENGINE=InnoDB;
