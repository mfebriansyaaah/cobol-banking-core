# Best-effort email delivery

Status: accepted
Date: 2026-10-16
Phase: Notification/Mailer hardening (FASE A).

## Context

Verification codes and notices were sent by `await`ing SMTP `sendMail` directly
in the request path, with no timeout and no error handling. A slow, hung or
failing SMTP either blocked the response or made a successful signup/reset
return 500, and delivery failures were invisible.

## Decision

- **Timeouts**: the transport sets `connectionTimeout`/`greetingTimeout`/
  `socketTimeout` to `SMTP_TIMEOUT_MS` (default 10000).
- **Best-effort**: a shared `deliver()` wraps `sendMail` in try/catch and
  **never throws**; on failure it logs a `mail_failed` event and returns false.
  The request path therefore never fails because of email.
- **Counters**: `gateway_mailer_sent_total` and `gateway_mailer_failed_total`
  (via `incCounter`) make delivery visible in `/metrics`.
- When there is no SMTP (or the send failed), the existing code-free
  `verification_code` log is still written, so the event is recorded.

## Consequences

- An SMTP outage no longer blocks or 500s signup/reset/email-change; the failure
  is logged and counted instead.
- The `_sent`/`_failed` counters surface deliverability problems.
- A code that could not be delivered is only visible in the logs (dev
  `MAIL_DEBUG`), not returned to the client — the user must retry, which the
  neutral resend flow supports.
- Covered by a mailer test that points at an unreachable SMTP and asserts no
  throw plus the failure counter.
