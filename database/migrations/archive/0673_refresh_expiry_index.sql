-- Housekeeping fix: the per-request cleanup in STORE-SESSION-LOGIC
-- (DELETE FROM refresh_sessions WHERE expires_at < NOW()) ran as a full
-- table scan on every refresh/login because expires_at had no index
-- (EXPLAIN type=ALL, 20k rows), while the sibling denylist table already
-- had idx_revoked_expires (type=range, 1 row). Under parallel load the
-- overlapping scans widen the InnoDB deadlock window for concurrent
-- session DML, surfacing as intermittent 500 SESSION_STORE_FAILED.
-- The index turns cleanup into a range scan without changing behavior.
ALTER TABLE refresh_sessions ADD INDEX IF NOT EXISTS idx_refresh_expires (expires_at);
