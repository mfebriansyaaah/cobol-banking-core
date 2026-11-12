-- Phase 2C slice: device/geo risk events (PR-092).
-- Raw IPs are never stored (ip_hash only); country/city/ASN are signals,
-- not verdicts. No auto-block: consumers read RISK_STATUS for step-up.
CREATE TABLE IF NOT EXISTS risk_events (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  country VARCHAR(16) NULL,
  city VARCHAR(64) NULL,
  asn VARCHAR(32) NULL,
  ip_hash CHAR(64) NOT NULL,
  flags VARCHAR(128) NOT NULL DEFAULT '',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_risk_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_risk_user (user_id, created_at)
) ENGINE=InnoDB;
