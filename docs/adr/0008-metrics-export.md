# Metrics export (push)

Status: accepted
Date: 2026-10-13
Phase: roadmap item - persistent observability.

## Context

The gateway kept `/metrics` counters in memory only: an external scraper can pull
them, but nothing survives the process on its own, and there is no push path for
environments that cannot scrape.

## Decision

- Keep the pull endpoint (`GET /metrics`, Prometheus text).
- Add an optional **push exporter**: when `METRICS_PUSH_URL` is set the gateway
  periodically POSTs the same Prometheus text to that URL
  (`METRICS_PUSH_INTERVAL_MS`, default 15s). The URL is a collector such as a
  Prometheus Pushgateway or an OTLP-HTTP bridge, which persists the series.
- The exporter is best-effort: a failing collector logs a warning and never
  throws (the interval callback is fired-and-forgotten and the timer is unref'd,
  so it does not keep the process alive).

## Consequences

- Metrics leave the process and are retained by the collector; multiple
  instances push under the same collector and can be aggregated there.
- Counters remain process-local until scraped/pushed (cumulative per process);
  the collector is responsible for aggregation/retention.
- No new runtime dependency: the push uses the platform `fetch`.
