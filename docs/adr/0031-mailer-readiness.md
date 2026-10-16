# Mailer readiness and startup warning

Status: accepted
Date: 2026-10-16
Phase: Notification/Mailer hardening (FASE C).

## Context

A missing or misconfigured SMTP was invisible: readiness checked only the DB and
the worker pool, and nothing warned when production ran without SMTP (codes were
silently undeliverable).

## Decision

- **`/ready` reports the mailer configuration** as `checks.mailer`
  (`configured` when `SMTP_HOST` is set, else `unset`). It is **informational**:
  delivery is best-effort (ADR 0029), so an unset mailer does not mark the
  instance not-ready.
- **Startup warning**: in production, if `SMTP_HOST` is not set, the server logs
  a `mailer_not_configured` warning at start, so the misconfiguration is visible
  before any user hits a flow.

## Consequences

- Operators can see whether email is configured from `/ready` and get an
  immediate startup warning in production without SMTP.
- Delivery failures are still visible via `gateway_mailer_failed_total`
  (ADR 0029); a wrong-credentials SMTP surfaces there rather than at startup.
- Covered by the readiness gateway test (asserts `checks.mailer`).
