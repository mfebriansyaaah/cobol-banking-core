# Configurable sender name and startup mailer diagnostics

Status: accepted
Date: 2026-10-16
Phase: Notification/Mailer hardening (FASE D).

## Context

The From address was a bare email with no display name (worse deliverability and
less recognisable to users), and the mailer configuration was not logged at
startup — only a production-without-SMTP warning existed.

## Decision

- `mailerFrom()` builds the sender: `Name <addr>` when `MAIL_FROM_NAME` is set,
  otherwise the bare `MAIL_FROM` (default `no-reply@cobol-banking.local`). Used
  by both `sendVerification` and `sendNotice`.
- At startup, when `SMTP_HOST` is set the server logs an informational
  `mailer_configured` line (host, port, secure) — no credentials.
- Deliberately **not** added: per-recipient send throttling. It would risk
  dropping the newest code (the previous one is invalidated), so the neutral
  resend flow plus the auth rate limit remain the mitigation; delivery health is
  observed via `gateway_mailer_sent_total`/`gateway_mailer_failed_total`.

## Consequences

- Emails carry a recognisable sender name and the mailer config is visible in
  the startup logs.
- Covered by a mailer unit test for `mailerFrom`.
