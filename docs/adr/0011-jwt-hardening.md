# JWT hardening: algorithm pinning and secret policy

Status: accepted
Date: 2026-10-15
Phase: Session & Token hardening (FASE C).

## Context

Access and refresh tokens are HMAC-signed JWTs. Two weaknesses were found in the
audit:

- Verification did not pin the accepted algorithm, leaving room for
  algorithm-confusion attacks (a token that claims `alg: none`, or that switches
  to another HS variant, must never be accepted).
- `assertSecureConfig` refused only missing/development secrets. It did not
  reject secrets that were too short or that were **the same** for access and
  refresh tokens, which collapses the two trust domains into one.

## Decision

- Every `jwt.verify` call passes `algorithms: ['HS256']` and every `jwt.sign`
  call sets `algorithm: 'HS256'`. A token signed with any other algorithm is
  rejected with `INVALID_TOKEN`/`INVALID_REFRESH_TOKEN`.
- In production, `assertSecureConfig` refuses to start unless `JWT_SECRET` and
  `REFRESH_SECRET` are each at least 32 characters, differ from the development
  defaults, and **differ from each other**.
- Outside production the checks stay permissive (tests and local development run
  with the default development secrets).

## Consequences

- Algorithm-confusion tokens are rejected; the accepted algorithm is explicit at
  both ends.
- Rotating one secret does not silently affect the other, and a short secret no
  longer slips into production.
- Operators must supply two distinct 32+ character secrets in production
  (`middleware/.env`); the `.env.example` guidance covers this.
