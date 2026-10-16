# Operational hardening: process errors and metrics push

Status: accepted
Date: 2026-10-16
Phase: Observability/Operational hardening (FASE D).

## Context

Two operational gaps remained:

- An unexpected process-level failure (`uncaughtException`/`unhandledRejection`)
  crashed silently — no structured log.
- The metrics push (`pushMetrics`) had no timeout and no overlap guard: a slow or
  hung collector could pile up requests every interval.

## Decision

- **Process errors**: `uncaughtException` logs a structured `event: process_error`
  line (kind, message, stack), shuts the worker pool down, and exits non-zero
  (the process is in an undefined state). `unhandledRejection` logs the same
  event without exiting.
- **Metrics push**: `pushMetrics(url, logger, timeoutMs = 5000)` aborts the fetch
  after the timeout; `startMetricsExporter` keeps an `inFlight` flag and skips a
  cycle while the previous push is still running.
- **Pool shutdown**: `close()` sets the pool gauges (`workers`/`busy`/`queued`)
  to zero so metrics reflect shutdown.

## Consequences

- Process-level failures are visible in logs (and alerts) instead of silent
  crashes; the process still exits so an orchestrator can restart it.
- A hanging collector no longer accumulates overlapping pushes; each push is
  bounded to 5s.
- Covered by an observability test asserting that a hung collector makes
  `pushMetrics` abort rather than hang.
