# Session security and authentication telemetry

Status: accepted
Date: 2026-10-20
Phase: Gate 2 (access control). Extends `A-P0-ACCESS` and `D-P0-AUDIT` in
`docs/TRACEABILITY.md`.

## Context

Sessions are already revoked per device (`REVOKE_USER_SESSION`), everywhere
(`REVOKE_ALL_SESSIONS`), and on reuse (`CONSUME_SESSION`). Three gaps remain:

1. There is no "sign out my other devices" action: a user who suspects a
   stolen device must revoke everything and log in again on every device.
2. An administrator's session has no idle bound separate from the refresh
   token's absolute lifetime, so an unattended admin tab stays usable for the
   full refresh window.
3. Authentication events are only partly visible: failed logins and refusals
   are audited, but successful logins, step-ups, and reset requests are not,
   and the gateway has no per-reason authentication failure counter.

## Decision

1. **Revoke others, keep this device.** `REVOKE_OTHER_SESSIONS` revokes every
   refresh session of the account except the presented family. The caller's
   own access tokens keep working; the other devices fail their next refresh
   or request. Self-service, or an admin not lower-ranked than the target.
2. **An idle bound for administrators, enforced at the refresh boundary.**
   `CONSUME_SESSION` records `last_seen_at` and, for `SUPER_ADMIN`/`MANAGER`,
   refuses a refresh whose previous activity is older than
   `ADMIN_IDLE_TIMEOUT_SECONDS` (default 1800; `0` disables). A refused
   refresh revokes the family, bumps the token version, and audits
   `SESSION_IDLE_TIMEOUT`. The access-token lifetime (15 minutes by default)
   bounds the residual exposure between refreshes; the idle window is the
   policy bound, and this limit is documented rather than hidden.
3. **A new device is announced, once.** `LOGIN_NOTICE` records the
   `(email, user agent, IP)` fingerprint in `known_devices`. The first
   sighting enqueues a `NEW_DEVICE` notification in the transactional outbox;
   repeats from the same fingerprint do not. The notice carries no code and
   only the IP, never the user agent or any credential.
4. **The audit taxonomy names the security events.** Successful logins
   (`AUTH_LOGIN_SUCCESS`), step-up outcomes (`STEP_UP_OK`, `STEP_UP_FAILED`),
   and reset requests (`PASSWORD_RESET_REQUESTED`) are appended to the
   existing trail; failed logins and refusals keep their existing rows.
5. **The gateway counts authentication failures by reason.** Every failed
   result in the authentication family increments
   `gateway_auth_failures_total{reason=...}`, so operators can see credential
   guessing, MFA guessing, lockouts, and replay attempts separately in
   `/metrics`. The counter is telemetry; it never makes an authorization
   decision.

## Why the idle check is at the refresh boundary

Per-request idle tracking would mean a write on every authenticated call, and
the access token is a self-contained credential the gateway verifies without
the database. Enforcing the idle window when the refresh token is exchanged is
the point where the session is already revalidated in COBOL, keeps the rule in
the core, and needs no per-request write. The access-token lifetime is the
documented residual window.

## Consequences

- Migration `0043`: `refresh_sessions.last_seen_at`, a `known_devices` table.
- Two COBOL actions (`REVOKE_OTHER_SESSIONS`, `LOGIN_NOTICE`), an idle check
  in `CONSUME_SESSION`, and four new audit action names.
- Two gateway surfaces: `POST /sessions/revoke-others` and the internal
  `LOGIN_NOTICE` call after a successful login or refresh; one counter.
- `A-P0-ACCESS` stays `partial`: the review cadence and the accountable owner
  are Gate 0 decisions. The idle window is configurable data, not a claim
  that a particular regulator's number has been approved.
