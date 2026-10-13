-- Migration 0006: revocable access tokens.
-- Each user carries a token_version embedded in issued access tokens. Bumping
-- it (on logout / force-revoke) invalidates every access token already issued,
-- closing the window where a stateless token stayed valid until it expired.
ALTER TABLE users ADD COLUMN token_version INT NOT NULL DEFAULT 1;
