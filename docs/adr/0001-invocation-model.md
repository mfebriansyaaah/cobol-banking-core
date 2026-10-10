# Per-request working directory for COBOL invocation

Status: accepted
Date: 2026-10-10
Phase: 0 (decision) — pre-requisite for the api-gateway and for any HTTP transport.

## Context

The shipped binary (`cobol/bin/main_logic`) reads `input.txt` and writes `output.txt`
by **relative path** and handles one request per process. Two concurrent processes in
the same working directory therefore fight over the same two files. Any future
api-gateway (see `SPEC-api-gateway.md`) needs a concurrency-safe way to invoke it.

## Decision

Invoke each request as its **own process with a unique working directory** that contains
that request's `input.txt`; call the binary by **absolute path**. The binary keeps using
relative paths and needs **no source change**.

## Evidence (empirical, against the real binary)

- 20 parallel requests, **separate cwd** per request → **20/20 correct**.
- 20 parallel requests, **shared cwd** → **0/20 correct** (outputs clobber each other).

Reproduce: create `N` dirs each holding `CHECK_BALANCE|sender@test.com|||` in `input.txt`,
spawn `( cd dir && /abs/path/cobol/bin/main_logic )` for all `N`, then read each
`dir/output.txt`.

## Considered options

- **Long-running COBOL server** (socket/pipe line protocol): rejected *for now* — requires
  reworking the read-once-then-exit model of `main_logic.cob`; larger surface than the
  problem currently needs.
- **Single serialized worker queue**: rejected as the default — correct but gives up
  concurrency entirely.
- **Env var / CLI arg for the file paths**: requires changing the COBOL contract; the cwd
  trick needs none.
- **Per-request temp files passed by path**: viable, but more code than cwd isolation.

## Consequences

- The gateway is just `mkdtemp` → spawn with `cwd` → read `output.txt` → cleanup.
- **Process-per-request has spawn + connection overhead.** Acceptable until throughput
  demands a server model; revisit this ADR if that happens.
- This does **not** fix DB-level races (double-spend). That is a separate concern, handled
  by transactions + row locks in the `wallet_core` atomic-transfer phase
  (`SPEC-wallet-core.md`).
- Temp directories must be cleaned up after each request.
