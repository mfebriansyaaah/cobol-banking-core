# Dormant account lifecycle

Status: accepted
Date: 2026-10-20
Phase: Gate 2 (account lifecycle). Extends `A-P1-LIFECYCLE` in
`docs/TRACEABILITY.md`.

## Context

An account that has not signed in for a long time is a standing target: the
credential still exists, the sessions may still be alive, and nobody is
watching it. Access review covers privileged accounts, but ordinary customer
accounts have no dormancy handling.

Suspending silently would be hostile and error-prone: a customer returning
after a long absence would find a locked account with no warning. The
lifecycle is therefore two-phase and data-driven.

## Decision

1. **Two phases with a grace window.** `MARK_DORMANT` flags accounts whose
   last sign-in is older than `DORMANT_AFTER_DAYS` and queues a notice to each
   address; it never changes the account status. `SUSPEND_DORMANT`, after the
   grace window, suspends accounts that were flagged and still have not signed
   in. `REACTIVATE_DORMANT` clears a dormant suspension.
2. **The policy is configuration, disabled by default.** `DORMANT_AFTER_DAYS`
   (default `0`, meaning off) and `DORMANT_GRACE_DAYS` (default `14`). The
   actions refuse with `POLICY_DISABLED` while the window is off, so an
   operator must opt in explicitly.
3. **Privileged accounts are never auto-suspended.** Both phases exclude
   `SUPER_ADMIN` accounts: the access-review workflow owns privileged
   accounts, and a bulk update must not race the last-admin guard.
4. **The notice precedes the restriction.** The outbox row carries the
   `DORMANT_NOTICE` purpose and no code. A failed enqueue clears the flag so
   the next run retries instead of losing the warning.
5. **Every step is audited and attributed** to the acting `SUPER_ADMIN`
   (`DORMANT_NOTICE`, `DORMANT_SUSPENDED`, `DORMANT_REACTIVATED`).

## Consequences

- Migration `0046`: `users.dormant_notified_at` and the
  `(status, last_login_at)` index.
- Three COBOL actions in `cobol/src/user_core.cob` and their gateway routes
  (`/admin/dormancy/{mark,suspend,reactivate}`, step-up protected).
- The outbox worker delivers `DORMANT_NOTICE` with a plain-text warning.
- `A-P1-LIFECYCLE` remains `partial`: the retention period and the exact
  dormancy/grace numbers are owner decisions, and the tracer still records the
  missing application/opening product.
