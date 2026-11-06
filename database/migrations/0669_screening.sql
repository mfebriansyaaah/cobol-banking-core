-- Phase 2C slice: sanctions/PEP screening checks (PR-090).
-- screening_checks records every provider verdict (fail-closed: provider
-- errors land as MANUAL_REVIEW, never CLEAR). Query terms are hashed for
-- audit (name+DOB needed by the provider; NIK never leaves the process).
CREATE TABLE IF NOT EXISTS screening_checks (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  provider VARCHAR(32) NOT NULL,
  query_hash CHAR(64) NOT NULL,
  result ENUM('CLEAR','POTENTIAL_MATCH','CONFIRMED_MATCH','FALSE_POSITIVE','MANUAL_REVIEW') NOT NULL,
  score DECIMAL(5,2) NULL,
  provider_ref VARCHAR(128) NULL,
  reviewed_by VARCHAR(100) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_screening_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_screening_user (user_id, created_at)
) ENGINE=InnoDB;
