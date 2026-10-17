# Transactional notification outbox (Gate 2)

Status: accepted
Date: 2026-10-17
Phase: Gate 2 — production controls (partial).

## Context

`PRD_Enterprise.md` section 4.E requires durable notifications: a
transactional outbox/queue, bounded retries, delivery status, dead-letter
handling, redaction, and operational alerting. Verification email was sent
inline from the gateway request path: an SMTP outage neither failed the
request (good) nor left any recoverable record (bad), and delivery had no
observable state at all.

## Decision

- `notification_outbox` (migration 0034): the core inserts one row per
  notification inside the same transaction as the business action that
  requires it (signup/resend/forgot-password/email-change codes, plus the
  abandoned-address notice). A committed action can never lose its
  notification; a rolled-back one never emits.
- `middleware/outbox_worker.js` (plus `scripts/outbox_worker.sh`)
  dispatches due rows through the existing mailer and marks the outcome
  (`SENT`/`FAILED` with backoff, `DEAD` past the attempt budget) via new
  COBOL actions `OUTBOX_CLAIM`/`OUTBOX_MARK`; `LIST_OUTBOX` (SUPER_ADMIN)
  exposes deliveries without codes. Stale `SENDING` claims are reaped.
- Bounded retries with backoff (`OUTBOX_MAX_ATTEMPTS`, default 5);
  per-run batching (`--limit`); redaction by construction (operational
  logs carry id/recipient/purpose only; read APIs never expose codes);
  alerting via structured `outbox_dead_letter`/`outbox_failed` log events
  plus the dead-letter rows themselves.
- The gateway no longer sends mail inline (its responses got faster and
  deterministic); `GET /admin/outbox` is the operator view. A log
  transport exists for development and tests only — it must never stand
  in for delivery in production, since it marks mail delivered.
- Deliberately out of scope: SMS/push channels (same table fits them),
  per-recipient preferences, template management, and pager integration
  (log-based alerts are the current contract).

## Consequences

- E-P1-NOTIFY is satisfied in code (owner approval still outstanding on
  every row). `tests/test_outbox.sh` (23 checks) covers the lifecycle;
  the gateway suite proves an end-to-end signup → worker → verify loop.
- No successful money movement can be rolled back by a mail failure: the
  movement commits first and the notification follows, observably.
