# Error observability: error codes in logs and metrics

Status: accepted
Date: 2026-10-15
Phase: Observability/Operational hardening (FASE A).

## Context

The gateway logged one structured line per request (method, route, status,
durations) but **not the error code**, and the Express error handler returned a
JSON error **without logging the cause**. A spike in 5xx (or 4xx) could not be
diagnosed from the logs or alerts alone.

## Decision

- **Request log**: the `http_request` line now carries an `error` field with the
  failing code (business code from COBOL, or a transport code), and the level is
  `error` for responses >= 500.
- **Error handler**: every thrown/transport error is logged as an
  `event: gateway_error` line with the code, HTTP status, message and stack, in
  addition to the JSON response.
- **Metric**: a `gateway_errors_total{code="..."}` counter is exported from
  `/metrics` (and pushed), incremented for every failed response — the COBOL
  business errors and the transport errors alike.
- The failed code is carried on `res.locals.errorCode` so the request observer
  can include it in the single log line.

## Consequences

- Failed requests are attributable by code from both logs and metrics; 5xx
  causes (timeout, COBOL unavailable, internal) are visible with a stack.
- The error cardinality is bounded by the set of business/transport codes.
- Covered by an observability test that drives a failing request and asserts the
  counter; the per-process metric reset limitation (FASE O3) is unchanged.
