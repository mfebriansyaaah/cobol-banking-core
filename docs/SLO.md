# Service-Level Objectives — baseline (PR-045)

> Measurement floor, not a marketing claim. Numbers below are measured on
> stated hardware; CI re-verifies the budgets on every run. If hardware
> changes, re-baseline deliberately and review the diff (same discipline
> as `tests/perf/baseline.json` with `PERF_UPDATE=1`).

## Method

- Gateway load: `bash tests/perf/load_gateway.sh` serves the real gateway
  (Express + COBOL pool + MariaDB) on a random localhost port and hammers
  `GET /health` (one COBOL/DB round-trip per request) with autocannon.
- Reference profile: **600 s × 20 connections** (~100 RPS class).
- COBOL action latency: `bash tests/perf/bench.sh` (P50/P95/P99 per action,
  regression budget p50 +20% / p95 +50% in `tests/perf/baseline.json`).

## Locked baseline

Reference run: 600 s × 20 conns against `/health`, localhost, seeded DB
(2026-11-05, dev machine): **3.654.333 requests, 0 errors, 0 timeouts,
0 non-2xx, p99 6 ms**. Shutdown drain measured separately: **104 ms**.

| Signal                              | Budget     | Measured (reference)                      |
| ----------------------------------- | ---------- | ----------------------------------------- |
| Read p95 (`/health`, balance, list) | < 300 ms   | ≤ 6 ms (bounded by p99, same run)         |
| Read p99                            | < 600 ms   | 6 ms                                      |
| Write p95 (transfer, login)         | < 800 ms   | not profiled at load yet                  |
| Write p99                           | < 1.500 ms | not profiled at load yet                  |
| Error rate                          | < 0,1%     | 0% (3,65M req, 0 non-2xx)                 |
| DB deadlocks during load            | 0          | 0 surfaced (any deadlock fails a request) |
| Graceful shutdown (in-flight drain) | < 10 s     | 104 ms                                    |

## Regression rule

Fail the run when measured p95 regresses **>10%** over this baseline or
error rate exceeds **0,1%**. Investigate before re-baselining; a slower
machine is a re-baseline reason, a slower commit is a bug.

## Non-goals

- This profile does not prove production capacity (single shared CI-class
  host, localhost network, seeded database).
- 10-minute runs are not part of the per-PR gate; they run on demand and
  before releases. The per-PR gate keeps the bench.sh budgets.
