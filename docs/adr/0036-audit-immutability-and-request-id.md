# Append-only audit trail and validated request ids

Status: accepted
Date: 2026-10-16
Phase: Cross-domain security hardening (FASE D).

## Context

Two hygiene gaps remained from the cross-domain security audit:

- `audit_trail` had no in-database immutability guard, unlike `ledger`, so a
  row could be edited in place directly through the database.
- `X-Request-Id` was taken from the caller verbatim, echoed back and written to
  the structured log — an unbounded, unvalidated value (log bloat / forging
  surface).

## Decision

- **Audit immutability**: migration `0028_audit_append_only.sql` (mirrored in
  `schema.sql` for fresh installs) adds a `BEFORE UPDATE` trigger on
  `audit_trail` that raises `SQLSTATE 45000`, exactly like the ledger trigger.
  `DELETE` stays allowed so the `BEFORE DELETE ON users` snapshot trigger can
  move rows into `audit_trail_archive` via the cascade. A correction is a new
  appended entry.
- **Request id**: a caller-supplied `X-Request-Id` is echoed only when it
  matches `^[A-Za-z0-9._-]{1,64}$`; otherwise a fresh UUID is minted. This
  bounds length and charset before the value reaches response headers or logs.

## Consequences

- Audit evidence cannot be silently rewritten; a failed `UPDATE` is a hard
  database error and the row is unchanged (covered by
  `tests/test_audit_integrity.sh`).
- Log lines and the `X-Request-Id` response header carry either a trusted,
  well-formed caller id or a generated UUID — never an oversized/forged value
  (covered by `middleware/test/observability.test.js`).
- The remaining OTP-throttling item is documented as a deliberate gap: a wrong
  MFA code at **login** already counts as a failed login (per-account lockout);
  `MFA_ENROLL_CONFIRM`/`MFA_DISABLE` are owner-only and share the per-IP API
  limiter.
