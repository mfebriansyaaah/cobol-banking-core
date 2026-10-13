-- Migration 0009: per-token access-token denylist.
-- Complements users.token_version (all-tokens revocation) with the ability to
-- revoke a single access token by its jti before it expires. Rows are pruned
-- once expired. The table is the shared source of truth across gateway
-- instances; a distributed store (e.g. Redis) can replace it behind the
-- gateway's tokenStore seam.
CREATE TABLE IF NOT EXISTS revoked_access_tokens (
    jti VARCHAR(50) PRIMARY KEY,
    email VARCHAR(100) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    revoked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_revoked_user FOREIGN KEY (email) REFERENCES users(email) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_revoked_expires ON revoked_access_tokens (expires_at);
