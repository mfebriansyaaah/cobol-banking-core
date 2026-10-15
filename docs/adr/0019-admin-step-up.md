# Step-up (re-authentication) for privileged admin actions

Status: accepted
Date: 2026-10-15
Phase: Admin/Governance hardening (FASE G).

## Context

Privileged admin writes (role change, status change, unlock, MFA reset, audit
archiving, transfer reversal) were protected only by the bearer access token
(15m) plus MFA at login. A stolen access token was therefore enough to perform
them. There was no re-authentication step.

## Decision

- Add `VERIFY_REAUTH(email, password, mfaCode)` in auth_core: it re-checks the
  caller's own password (PBKDF2 with a legacy fallback) and, when MFA is on, a
  valid TOTP. It issues **no tokens** and does **not** touch lockout state.
- Add `POST /auth/step-up` (bearer-authenticated): it calls `VERIFY_REAUTH` for
  the token's own email and, on success, mints a **short-lived step-up token**
  (`signStepUp`, TTL `STEP_UP_TTL_SECONDS`, default 300s) carrying a distinct
  `purpose: 'step-up'` claim plus the caller's token version.
- Add a `requireStepUp` gateway gate: the privileged writes must present the
  proof in the `X-Step-Up` header (or `stepUpToken` in the body); it must verify,
  match the access token's email, and match its token version. Missing/invalid →
  `401 STEP_UP_REQUIRED`.
- `requireAuth`/`verifyAccess` reject any token carrying `purpose`, so a step-up
  token can never be used as an access token (and vice versa).

## Consequences

- A stolen access token alone is no longer enough for a privileged write: the
  attacker also needs the password (and TOTP where MFA is enabled) within the
  step-up window.
- The step-up proof is stateless and short-lived; a token-version bump (status
  change, password reset, revoke-all) invalidates it.
- `VERIFY_REAUTH` deliberately does not arm the lockout, so it cannot be used to
  lock an account; it is rate-limited by the auth limiter instead.
- Known gap: admin MFA is not mandated, so an admin without MFA only needs the
  password to step up; covered by `tests/test_stepup.sh` and gateway tests.
