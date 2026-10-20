-- Migration 0043: session security and authentication telemetry (ADR 0075).
-- refresh_sessions.last_seen_at is the idle basis: CONSUME_SESSION records it
-- on every successful refresh and, for administrators, refuses a refresh
-- whose previous activity is older than ADMIN_IDLE_TIMEOUT_SECONDS.
--
-- known_devices is the durable "have we seen this sign-in fingerprint before"
-- record. The first sighting of (email, user_agent, ip) enqueues a NEW_DEVICE
-- notice in the transactional outbox; a repeat does not. It holds no
-- credential and no code.
ALTER TABLE refresh_sessions
    ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMP NULL DEFAULT NULL;

CREATE TABLE IF NOT EXISTS known_devices (
    email VARCHAR(100) NOT NULL,
    user_agent VARCHAR(255) NOT NULL DEFAULT '',
    ip VARCHAR(45) NOT NULL DEFAULT '',
    first_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (email, user_agent, ip)
) ENGINE=InnoDB;
