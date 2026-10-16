# Counted rate-limiter fail-open

Status: accepted
Date: 2026-10-16
Phase: Rate limiting & abuse audit (FASE C).

## Context

The limiter deliberately fails open: a broken store (e.g. Redis down) lets the
request through so a counter outage cannot take the API down. But the fail-open
was silent — during a store outage every brute-force protection (auth limiter,
API limiter, probe limiter) was gone with nothing to observe, so operators
could not know the API was unprotected.

## Decision

- `createRateLimiter` increments `gateway_ratelimit_failopen_total` on every
  store failure before passing the request through. The single choke point
  covers both the auth and API limiters.
- The counter flows through the existing exposition (`/metrics`, SUPER_ADMIN)
  and the push exporter like every other counter — no new plumbing.
- Deliberately counter-only: logging each request during an outage would flood
  the logs; a monotonic counter is the right signal for "protection was absent
  N times".
- Covered by two gateway tests: a broken store still lets the request through,
  and two failures export `gateway_ratelimit_failopen_total 2`.

## Consequences

- A dead store is a visible, alertable condition instead of a silent loss of
  brute-force protection. Fail-open availability semantics are unchanged.
- Gateway suite 101 -> 103 (shell 595 unchanged; full run 698 assertions).
