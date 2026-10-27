CREATE TABLE IF NOT EXISTS product_catalog (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_ref VARCHAR(40) NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    product_type VARCHAR(20) NOT NULL,
    list_price DECIMAL(18,4) NOT NULL DEFAULT 0,
    discount_price DECIMAL(18,4) NOT NULL DEFAULT 0,
    status ENUM('OPEN','ACTIVE','RETIRED','DELETED') NOT NULL DEFAULT 'OPEN',
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activated_at DATETIME NULL,
    retired_at DATETIME NULL,
    retire_reason VARCHAR(255) NULL,
    version INT NOT NULL DEFAULT 1,
    deleted_at DATETIME NULL,
    UNIQUE KEY uq_product_catalog_ref (product_ref),
    INDEX idx_product_catalog_status (status, product_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS product_catalog_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id BIGINT NULL,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    detail VARCHAR(255),
    old_value VARCHAR(255) NULL,
    new_value VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_product_catalog_audit_actor (actor_email, created_at),
    INDEX idx_product_catalog_audit_product (product_id, created_at)
) ENGINE=InnoDB;
