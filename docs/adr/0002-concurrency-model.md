# ADR 0002: Concurrency model for the COBOL core

## Status
Accepted

## Context
The COBOL core is not thread-safe: modules use process-global working storage and
the C bridge previously used process-global buffers. Running multiple requests in
one process would race on that state.

## Decision
Concurrency is provided by **process isolation**, not threads:

- File mode (ADR-0001): one process per request.
- Worker pool: several long-lived `main_logic --serve` processes, each handling
  requests serially; the pool dispatches at most `pipeline` in-flight requests
  per worker, but the worker processes them one at a time.

The C bridge (`sql_bridge.c`) is made reentrant with thread-local storage so it
does not add a second, hidden serialization point and so the same code can be
embedded in a threaded host without data races on its own buffers. The COBOL
modules themselves remain single-threaded per process.

## Consequences
- Horizontal scaling is by adding workers/processes, not threads.
- A worker crash affects only its in-flight requests; the pool replaces it.
- Full in-process threading of the COBOL core is out of scope.
