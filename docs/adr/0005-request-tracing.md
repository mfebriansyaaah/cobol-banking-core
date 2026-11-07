# ADR 0005: Correlation-id request tracing instead of distributed tracing

## Status

Accepted

## Context

The audit gap list asks for tracing (Observability 1→2), allowing a
documented decision against it. The topology matters: one gateway process
fans out to a local pool of `main_logic --serve` workers over stdio and to
MariaDB over a socket. There are no chained microservices to propagate a
trace context through — integrations (pwned, Turnstile, mailer, quota) are
fail-open side calls, not hops in a request path. Shipping an OpenTelemetry
collector for a single-process topology would add a dependency and PII
surface (trace export of credential-adjacent fields) with no second span to
join.

## Decision

No distributed-tracing framework. Request tracing is correlation-id based:

- The observer mints a UUID (or echoes a well-formed caller-supplied
  `X-Request-Id`, bounded to 64 chars of `[A-Za-z0-9._-]`), returns it as
  the `X-Request-Id` response header, and stashes it on `req.requestId`.
- Every `http_request` log line and both `gateway_error` emission sites
  (thrown-error middleware and COBOL-mapped 5xx forensics) carry the same
  `id`, so an error joins to its request by equality.
- The gateway/COBOL split is timed per request (`X-Cobol-Ms` header,
  `gateway_cobol_duration_ms` histogram) instead of a child span.

## Consequences

- A request's full gateway story (access line + error line + latency
  split) is recoverable from structured logs with one equality predicate.
- Integration side logs (`pwned_failopen`, `turnstile_*`, quota alerts)
  do not carry the id — those call sites have no request in scope, and
  threading one through is explicitly deferred as low value (they are
  fail-open and counted in metrics).
- The COBOL side carries no request id: the 6-slot pipe protocol has no
  slot for one, and changing the contract of 545 actions for a label is
  rejected. COBOL-side forensics stay keyed by business identifiers
  (email, txn ref, hold id), joinable at the operator level.
- Evidence: `middleware/test/observability.test.js` (echo/replace plus
  request↔error id-join tests for caller-supplied and minted ids).
