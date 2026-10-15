# Privileged-account hardening and admin recovery

Status: accepted
Date: 2026-10-15
Phase: Admin/Governance hardening (FASE F).

## Context

The audit found the operational surfaces open and the administrator role hard to
recover:

- `/metrics` was readable by any authenticated user (topology/traffic
  disclosure).
- There was no supported way for an administrator to recover a locked-out user
  or a user who lost their MFA device — lockout is time-based and MFA is
  owner-managed only.
- The `MANAGER` role's capabilities were undocumented.

## Decision

- **`/metrics` is SUPER_ADMIN-only**: a `requireRole('SUPER_ADMIN')` middleware
  checks the caller's role live via `CHECK_ROLE` (self-check) and returns 403
  otherwise.
- **Admin recovery actions** (user_core): `UNLOCK_USER` clears
  `failed_logins`/`locked_until`; `ADMIN_RESET_MFA` clears
  `mfa_enabled`/`mfa_secret`. Both require an admin that is **not lower-ranked**
  than the target (the same rule as `SET_USER_STATUS`), are transactional, and
  are audited with subject + actor. Exposed as `POST /admin/unlock` and
  `POST /admin/mfa-reset`.
- **`/metrics` route label**: unmatched requests collapse to a constant
  (`unmatched`) so a raw path cannot become a high-cardinality metric or log
  label carrying PII.
- **Documented `MANAGER` capabilities** in `docs/STATUS.md`: it may read any
  user, set status, revoke sessions and recover users, but never a higher-ranked
  account and never the SUPER_ADMIN-only operations (role change, reversal,
  reconcile, audit archive/read).

## Consequences

- Metrics are no longer disclosed to ordinary users.
- An administrator can recover a locked or MFA-less user without database
  access; a lower-ranked admin still cannot touch a higher-ranked account.
- No per-action step-up yet: privileged actions rely on the login-time MFA and
  a 15-minute access token, and admin MFA is not mandated. This is a known gap
  (re-authentication/step-up is a future phase). Covered by
  `tests/test_admin_recovery.sh` and gateway tests.
