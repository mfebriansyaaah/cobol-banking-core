-- Migration 0002: refresh_sessions table for refresh-token revocation.
-- Records each issued refresh token's jti so it can be revoked (logout) or
-- rotated (single-use) server-side. Applied to the development database 2026-10-11.
CREATE TABLE IF NOT EXISTS refresh_sessions (
    jti VARCHAR(50) PRIMARY KEY,
    email VARCHAR(100) NOT NULL,
    revoked BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_refresh_user FOREIGN KEY (email) REFERENCES users(email) ON DELETE CASCADE
) ENGINE=InnoDB;
