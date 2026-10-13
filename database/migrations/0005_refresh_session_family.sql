-- Migration 0005: refresh-session families for reuse detection.
-- Every rotated refresh token keeps the family id of the login that started it.
-- Presenting an already-revoked token is treated as reuse (likely theft) and the
-- whole family is revoked by CHECK_SESSION. Existing rows form singleton
-- families (family = jti).
ALTER TABLE refresh_sessions ADD COLUMN family VARCHAR(50) NULL AFTER jti;
UPDATE refresh_sessions SET family = jti WHERE family IS NULL;
ALTER TABLE refresh_sessions MODIFY family VARCHAR(50) NOT NULL;
CREATE INDEX idx_refresh_family ON refresh_sessions (family);
