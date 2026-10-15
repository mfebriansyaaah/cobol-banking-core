# Refresh families: absolute lifetime and rotation cap

Status: accepted
Date: 2026-10-15
Phase: Session & Token hardening (FASE D).

## Context

Refresh tokens rotate: each `/auth/refresh` consumes the old `jti` and issues a
new one in the same `family` (ADR 0006). Rotation alone has no ceiling — a
stolen family could be kept alive indefinitely by rotating forever, each new
token comfortably inside its own 7-day expiry. A session should not outlive a
bounded window, and a very chatty client should be forced to re-authenticate
occasionally.

## Decision

- Each login starts a **family**; `refresh_families` records the family's
  `created_at` and a `rotations` counter. `STORE_SESSION` registers the family
  (`INSERT IGNORE`) and `CONSUME_SESSION` counts each successful rotation.
- After a successful atomic consume, `CONSUME_SESSION` refuses the rotation (and
  revokes the whole family) with `ERROR|SESSION_FAMILY_EXPIRED` when the family
  is older than `REFRESH_ABSOLUTE_TTL_DAYS` (default 30) or has already rotated
  `REFRESH_MAX_ROTATIONS` times (default 100). Either value set to 0 disables
  that check.
- The check **fails closed**: if the family's state cannot be read, the rotation
  is refused rather than allowed.

## Consequences

- A refresh session cannot be extended without bound: at most 30 days of age and
  100 rotations by default, whichever comes first, then a fresh login.
- The refusal revokes the family, so a client that keeps trying is forced to
  log in again; other families (other devices) are unaffected.
- The limits are read from the environment like the transfer caps, so they can
  be tuned per deployment without a code change.
