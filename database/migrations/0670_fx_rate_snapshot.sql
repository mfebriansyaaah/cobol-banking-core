-- Phase 2C slice: FX reference snapshots (PR-091, Frankfurter).
-- Daily mid-rate reference only (never settlement basis). Latest row per
-- pair wins; age > 24h reads STALE in FX_RATE_GET.
CREATE TABLE IF NOT EXISTS fx_rate_snapshots (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  base CHAR(3) NOT NULL,
  quote CHAR(3) NOT NULL,
  rate DECIMAL(18,6) NOT NULL,
  provider VARCHAR(32) NOT NULL,
  fetched_at DATETIME NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_fx_pair (base, quote, fetched_at)
) ENGINE=InnoDB;
