-- Phase 1: generic reference-data engine.
-- Replaces the per-entity generated CRUD with a type/value/version model:
-- effective dating, approval, translations, hierarchy, and audit.
-- The generated ref_core module stays in place until each domain is cut over.

CREATE TABLE IF NOT EXISTS ref_type (
    type_code VARCHAR(32) PRIMARY KEY,
    label VARCHAR(64) NOT NULL,
    description VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_value (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type_code VARCHAR(32) NOT NULL,
    code VARCHAR(64) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_ref_value (type_code, code),
    CONSTRAINT fk_ref_value_type FOREIGN KEY (type_code)
        REFERENCES ref_type(type_code) ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_value_version (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ref_value_id INT NOT NULL,
    version_no INT NOT NULL,
    label VARCHAR(128) NOT NULL,
    attributes TEXT,
    status ENUM('DRAFT','ACTIVE','RETIRED') NOT NULL DEFAULT 'DRAFT',
    effective_from DATE NOT NULL,
    effective_to DATE NULL,
    approved_by VARCHAR(100),
    approved_at DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_ref_version (ref_value_id, version_no),
    CONSTRAINT fk_ref_version_value FOREIGN KEY (ref_value_id)
        REFERENCES ref_value(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_translation (
    ref_value_id INT NOT NULL,
    locale VARCHAR(10) NOT NULL,
    label VARCHAR(128) NOT NULL,
    PRIMARY KEY (ref_value_id, locale),
    CONSTRAINT fk_ref_translation_value FOREIGN KEY (ref_value_id)
        REFERENCES ref_value(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_hierarchy (
    parent_value_id INT NOT NULL,
    child_value_id INT NOT NULL,
    PRIMARY KEY (parent_value_id, child_value_id),
    CONSTRAINT fk_ref_hier_parent FOREIGN KEY (parent_value_id)
        REFERENCES ref_value(id) ON DELETE CASCADE,
    CONSTRAINT fk_ref_hier_child FOREIGN KEY (child_value_id)
        REFERENCES ref_value(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ref_engine_audit (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type_code VARCHAR(32) NOT NULL,
    value_code VARCHAR(64) NOT NULL,
    action VARCHAR(32) NOT NULL,
    actor_email VARCHAR(100),
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ref_engine_audit_value (type_code, value_code)
) ENGINE=InnoDB;

INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('currency', 'Currency', 'ISO 4217 currency codes', TRUE),
('country', 'Country', 'ISO 3166 country codes', TRUE),
('holiday', 'Holiday', 'Holiday calendar entries', TRUE),
('fee_code', 'Fee Code', 'Fee schedule codes', TRUE),
('limit_type', 'Limit Type', 'Limit definitions', TRUE),
('product_type', 'Product Type', 'Product catalog types', TRUE);
