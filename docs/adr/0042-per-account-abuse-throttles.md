# Per-account resend cooldown and MFA failure counting

Status: accepted
Date: 2026-10-16
Phase: Rate limiting & abuse audit (FASE B).

## Context

Two operations were throttled per IP only, leaving per-account abuse open:

- `RESEND_VERIFICATION` and `FORGOT_PASSWORD` deleted the pending code and
  inserted a fresh one on every call — an unauthenticated caller could flood a
  victim's mailbox and grow `verification_logs` without bound.
- `MFA_ENROLL_CONFIRM`/`MFA_DISABLE` rejected bad TOTP codes without counting
  them, so the 6-digit code could be guessed at the full per-IP rate with no
  per-account consequence.

## Decision

- **Resend cooldown** (`RESEND_COOLDOWN_SECONDS`, default 60, 0 disables): when
  an unused code for the same email+purpose was created inside the window, the
  request returns the neutral `SUCCESS|CODE_SENT` without issuing or emailing
  a new code. Burned or absent codes still reissue, and neutrality is
  preserved (no existence oracle either way).
- **MFA failures count as failed logins**: a new `MFA-RECORD-FAILURE` paragraph
  mirrors `RECORD-LOGIN-FAILURE` semantics (guarded increment, no-op while
  locked, `AUTH_LOGIN_FAILED` audit) and both bad-code branches perform it.
  Three bad codes lock the account for 15 minutes; the response stays the
  uniform `INVALID_MFA`. Owner-only access means only a session holder can
  trip the counter, so this cannot be used for anonymous lockout-DoS (unlike
  the deliberately uncounted step-up path).
- Coverage: new `tests/test_resend_cooldown.sh` (7 checks, including the
  zero-disables path); `tests/test_mfa.sh` 16 -> 20 (counting, lock, expiry);
  the pre-existing resend test now exercises the reissue path explicitly.

## Consequences

- Mailbox flooding and table growth via resends are bounded per account, and
  distributed TOTP guessing against enrol/disable dies at the third failure.
- Shell 584 -> 595, gateway 101 unchanged; full run 696 assertions.
