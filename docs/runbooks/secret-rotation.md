# Secret rotation

Status: procedure. Overlap duration, roster, and approval of a real rotation
are owner decisions (Gate 0); the mechanics below are enforced by the code.

## What rotates

`JWT_SECRET` (access/step-up tokens) and `REFRESH_SECRET` (refresh tokens).
They are independent: rotate one without disturbing the other, or rotate both
together. Every other setting is data, not a key.

## Why the overlap is bounded

Rotating a signing secret invalidates every token minted with the old value.
To avoid forcing every user to log in at once, the old value can be staged as
`JWT_SECRET_PREVIOUS` / `REFRESH_SECRET_PREVIOUS` and remains accepted **only
until its deadline** `JWT_SECRET_PREVIOUS_UNTIL` /
`REFRESH_SECRET_PREVIOUS_UNTIL` (unix epoch seconds). Past that deadline the
value stops being honored even if it is left configured, so a forgotten
previous secret cannot stay valid forever. Signing always uses the primary
secret.

The deadline must cover the longest token a client could still present: at
least `REFRESH_TTL_DAYS` for `REFRESH_SECRET_PREVIOUS`, and
`REFRESH_ABSOLUTE_TTL_DAYS` if refresh families may outlive a single TTL.

## Planned rotation

1. Generate the new value (at least 32 characters, distinct from every other
   configured secret in the family).
2. Stage the overlap: set `JWT_SECRET_PREVIOUS` (or the refresh equivalent) to
   the current value and `*_PREVIOUS_UNTIL` to `now + overlap`.
3. Restart with the new primary secret. Tokens minted before the restart keep
   verifying until the deadline; new tokens use the new secret.
4. After the deadline, clear `*_PREVIOUS` and `*_PREVIOUS_UNTIL` (leaving them
   is harmless — the value is already ignored — but clearing keeps the
   configuration honest).
5. Record the rotation (date, operator, scope, deadline) as release evidence.

A restart with a previous secret but no valid deadline is **refused in
production**, so the overlap cannot be left open by accident.

## Emergency rotation (suspected compromise)

Do not stage an overlap: replace the primary secret outright and restart. Every
access, step-up, and refresh token signed with the leaked value fails
immediately; users re-authenticate. Also:

- revoke live sessions and bump token versions where the compromise is scoped
  to accounts (`REVOKE_ALL_SESSIONS`, `SET_USER_STATUS` / role changes do this);
- treat it as an incident (`incident-response.md`) and capture evidence
  (`audit_trail`, `refresh_sessions`, gateway logs) before rotating.

## Verification

- `./tests/env_check.sh` — every rotation setting is documented.
- `middleware/test/security.test.js` — the overlap is honored only until its
  deadline, a missing/malformed deadline disables it, production refuses a
  previous secret without a deadline, and no two secrets in the family may
  share a value.
