-- Migration 0022: refresh-token families with an absolute lifetime and a
-- rotation cap. Each login starts a family; every successful rotation
-- increments `rotations`. CONSUME_SESSION refuses (and revokes) a family that
-- is older than REFRESH_ABSOLUTE_TTL_DAYS or has rotated more than
-- REFRESH_MAX_ROTATIONS times, forcing a fresh login even though the current
-- refresh token would still be within its own expiry.
CREATE TABLE IF NOT EXISTS refresh_families (
    family VARCHAR(50) PRIMARY KEY,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    rotations INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_refresh_family_user FOREIGN KEY (email) REFERENCES users(email) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
