# Distributed rate limiting via a pluggable counter store

Status: accepted
Date: 2026-10-13
Phase: roadmap item - distributed rate limiting.

## Context

The gateway limited requests with an in-process fixed-window counter: correct
for one instance, but each process kept its own counters, so N instances allowed
N times the limit.

## Decision

- The limiter (`middleware/src/rateLimit.js`) counts through a **store** with a
  single method, `hit(key, windowMs) -> {count, resetAt}`.
- The default store is in-memory (`memoryStore()`); when `REDIS_URL` is set the
  limiter uses `redisStore()` (node-redis `INCR` + `PEXPIRE`), so every instance
  shares the counters. `storeFromEnv()` picks between them.
- The IP used as the key follows Express `trust proxy`, configured by
  `TRUST_PROXY` (off by default).
- If the store is unreachable the limiter **fails open** (allows the request):
  a broken counter must not take the API down.

## Consequences

- A single Redis makes the limit global; without it the behaviour is unchanged
  (per process).
- Fail-open is a deliberate availability/security trade-off; a stricter mode
  could return 503 instead.
- The auth limiter stays stricter than the general API limiter, as before.
