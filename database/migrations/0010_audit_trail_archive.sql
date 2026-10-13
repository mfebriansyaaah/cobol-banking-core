-- Migration 0010: audit-trail archive table.
-- audit_trail is append-only; ARCHIVE_AUDIT moves rows older than a retention
-- window into this immutable archive (no FK, so it survives user deletion),
-- keeping the live table bounded.
CREATE TABLE IF NOT EXISTS audit_trail_archive (
    audit_id BIGINT PRIMARY KEY,
    user_id INT NOT NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id VARCHAR(50),
    status ENUM('SUCCESS', 'FAILED') NOT NULL,
    created_at TIMESTAMP,
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_archive_created (created_at)
) ENGINE=InnoDB;
