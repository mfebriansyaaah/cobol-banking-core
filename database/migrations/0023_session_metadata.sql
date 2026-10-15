-- Migration 0023: session metadata for the session list.
-- Each refresh session records the client's user-agent and IP at the time it
-- was stored, so GET /sessions can show where each device is.
ALTER TABLE refresh_sessions
    ADD COLUMN user_agent VARCHAR(255) NULL,
    ADD COLUMN ip VARCHAR(45) NULL;
