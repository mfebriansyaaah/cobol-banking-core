# Rate-limited, cached public probes

Status: accepted
Date: 2026-10-16
Phase: Cross-domain security hardening (FASE A).

## Context

`/health` and `/ready` are necessarily public (orchestrators and load balancers
probe them without credentials). Both perform a COBOL/DB round-trip per call
(`/health` a `PING`; `/ready` a `PING` plus pool stats), and in file mode each
call spawns a core process. With no limiter, an anonymous caller could flood
them to exhaust worker processes and DB connections — an unauthenticated
amplification vector.

## Decision

- Both `/health` and `/ready` now pass through the shared API limiter
  (`API_RATE_LIMIT_*`, keyed per client IP, shared via Redis when configured),
  like the rest of the non-auth surface. `/live` stays exempt: it touches no
  dependency and is pure liveness, so it must never flap on a DB blip.
- `/ready`'s dependency checks are cached in-process for `PROBE_CACHE_MS`
  (default 1000), so a burst of probe calls performs at most one DB round-trip
  per window regardless of per-IP count.
- The 429 path returns the uniform envelope (`RATE_LIMITED`), the same as every
  other limited route.

## Consequences

- Anonymous flooding of the probes is bounded per client IP and by the cache
  window, while orchestrator intervals (seconds) stay well under the default
  generous limit.
- A misconfigured very-low `API_RATE_LIMIT_MAX` could now throttle probes; the
  default (600 / 15 min) leaves ample headroom for seconds-level probing.
- Covered by gateway tests: a normal probe responds 200, and a fresh app with
  `API_RATE_LIMIT_MAX=1` returns 429 on the second probe call.
