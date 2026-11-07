# Capacity (PR-070)

Reference profile (PR-045): ~100 RPS class at 20 conns, p99 6 ms reads on
the dev machine. Plan headroom, not hope.

## Signals to watch

- Pool saturation (`GatewayPoolSaturated` alert): raise `COBOL_POOL_SIZE`
  before latency climbs (pool stats on `/metrics`).
- DB connections vs `max_connections`; slow-query log reviewed monthly.
- Outbox age (oldest `PENDING` row): worker count or `--limit` tuning.
- Disk: DB growth + vault bucket growth week-over-week.

## Scaling moves (in order)

1. Vertical: pool size, DB buffer pool, worker `--limit`.
2. Read relief: statement/report endpoints paginate (LIMIT enforced).
3. Horizontal: stateless gateway replicas behind the proxy (sticky-free:
   sessions live in DB/Redis, not memory).

## Load evidence

`bash tests/perf/load_gateway.sh` + `tests/perf/baseline.json`
(`PERF_UPDATE=1` to re-baseline deliberately). Reference numbers live in
`docs/SLO.md`; write-path profiling is the known gap (tracked, not hidden).
