-- Phase 2C slice: corporate registry cache (PR-097, GLEIF).
-- LEI lookups cached for corporate onboarding. GLEIF is global and free but
-- not a substitute for AHU/akta (see docs/CORPORATE.md).
CREATE TABLE IF NOT EXISTS corporate_entities (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  lei CHAR(20) NOT NULL,
  legal_name VARCHAR(255) NOT NULL,
  status VARCHAR(32) NOT NULL,
  address VARCHAR(255) NULL,
  parent_lei CHAR(20) NULL,
  fetched_at DATETIME NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_corp_lei (lei),
  INDEX idx_corp_name (legal_name(64))
) ENGINE=InnoDB;
