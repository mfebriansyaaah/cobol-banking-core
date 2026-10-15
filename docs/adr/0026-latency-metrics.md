# Latency histograms and pool restart counter

Status: accepted
Date: 2026-10-15
Phase: Observability/Operational hardening (FASE B).

## Context

The only metrics were per-route request **counts**; request and COBOL latencies
(`durationMs`/`cobolMs`) were logged but not exported, so there were no p95/p99
or COBOL-latency signals for alerting and capacity. Worker-pool restarts
(crashes/timeouts) were also invisible.

## Decision

- Add fixed-bucket **histograms** rendered as Prometheus histograms:
  - `gateway_request_duration_ms` (the whole request),
  - `gateway_cobol_duration_ms` (the `X-Cobol-Ms` value, when present),
  with buckets 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000 ms plus
  `_sum`/`_count`/`+Inf`.
- Add a generic `incCounter(name)` and a `gateway_cobol_pool_restarts_total`
  counter, incremented whenever the pool replaces a dead worker.
- `metricsText` renders counters and histograms alongside the existing counters,
  gauges and error counters.

## Consequences

- Prometheus can compute request/COBOL latency percentiles and alert on them;
  a worker crash-loop is now visible via the restart counter.
- Buckets and counters live in-process (reset on restart), like the existing
  metrics; the push exporter still carries them to the collector.
- Covered by observability and pool tests.
