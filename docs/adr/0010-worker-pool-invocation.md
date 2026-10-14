# Worker-pool invocation (revisiting per-request processes)

Status: proposed (direction agreed; Phase 1 - serve mode - implemented; pool pending)
Date: 2026-10-14
Phase: roadmap item - throughput/scalability.
Relates to: ADR-0001 (per-request working directory).

## Context

ADR-0001 runs the COBOL core as **one process per request** (unique cwd, files
`input.txt`/`output.txt`). That is correct and concurrency-safe, but every
request pays process spawn + file I/O, and each non-transactional statement pays
a fresh DB connection.

A throwaway benchmark over the real binary and a prototype worker server
(`server.cob` + a bridge that reuses one connection, disposable) measured the
cost decomposition. Representative numbers, n=300, local machine:

| path | PING req/s (c=8) | CHECK_BALANCE req/s (c=8) |
|---|---|---|
| process-per-request (today) | 263 | 250 |
| warm worker pool (stdin/stdout) | 4662 | 4594 |
| + connection reuse | 7401 | 6879 |
| + pipelining | 9813 | 8528 |
| echo worker (harness/IPC ceiling, no COBOL/DB) | 12564 | 10640 |

Attribution: removing **spawn + file I/O** is the dominant win (~16-18x);
**connection reuse** adds ~1.3-1.6x; **pipelining** ~1.2-1.3x. The COBOL+DB work
itself is small relative to transport - the pool reaches ~70-80% of the harness
IPC ceiling (the echo worker). Concurrent requests are independent; correctness
under contention is already covered by the transaction/row-lock suites and is
not what this changes.

## Decision

Adopt a **worker-pool** model as the scale path, keeping process isolation:

- The binary gains a **stdin/stdout line protocol** mode: read
  `ACTION|p1|p2|p3|p4` lines, write one result line per request, reuse the same
  modules; a warm pool of N worker processes serves requests (no spawn, no temp
  files per request). **Phase 1 (serve mode, `main_logic --serve`) is
  implemented**; the gateway pool, connection pooling, and pipelining follow.
- The bridge gains **connection pooling** (per worker process) instead of
  connecting per statement.
- The gateway runs the pool and dispatches requests; pipelining is optional.

Isolation is preserved (one request at a time per worker process), so the bridge
globals remain safe. This supersedes ADR-0001 *for throughput*; ADR-0001 stays
the reference until this is implemented.

## Connection lifecycle (additional evidence)

A pooled connection must survive the database dropping it. Two prototype
bridges were compared: a naive pool (keeps the connection) and a
reconnect-aware one (`mysql_ping` before use; drop and reopen on failure). A
warm pool of 4 workers served `CHECK_BALANCE`; then every DB connection was
killed; then more requests were sent:

| bridge | before the kill | after all connections were killed |
|---|---|---|
| naive pool | 20/20 ok | **0/20** (`ERROR\|PREPARE_FAILED\|2006`, server gone away) |
| reconnect-aware pool | 20/20 ok | **20/20 ok** (recovered) |

The transactional path also works over a pooled connection: `TRANSFER`
(`SQL_BEGIN`/`COMMIT`) moved money exactly once and replayed idempotently
(one request per worker at a time, so the shared connection is safe).

This makes the following **required** in the real bridge:

- **health-check + reconnect** (`mysql_ping` before use; reconnect on failure),
  without which the pool dies on a DB restart or idle timeout;
- **transaction connection ownership**: return the connection to the pool after
  `COMMIT`/`ROLLBACK` (or use a dedicated per-transaction connection) instead of
  the prototype's "never close";
- **transient-error classification** (2006 gone away, 2013 lost connection, 1205
  lock wait) for a bounded retry, distinct from logic errors.

## Considered options

- **In-process (FFI Node↔COBOL)**: removes IPC entirely, but Node cannot host the
  COBOL runtime in-process without a foreign-function layer; not pursued.
- **Single long-running server with internal concurrency**: needs a re-entrant
  bridge (per-session buffers) and threading; larger surface than the pool.
- **Keep process-per-request**: fine for low load; the bottleneck at scale.

## Consequences

- Target throughput rises by up to ~15-37x, with far lower p95 under concurrency.
- Requires: protocol + pool in the binary/gateway (change `build.sh`,
  `middleware/src/invoker.js`), and connection lifecycle (reconnect, transaction
  interplay) in the bridge - the prototype's blunt connection reuse is not
  production-ready.
- The real ceiling becomes IPC/DB, not COBOL; further gains need FFI or a
  database-side pushdown.
