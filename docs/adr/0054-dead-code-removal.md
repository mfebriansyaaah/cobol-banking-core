# Remove dead bridge and crypto code

Status: accepted
Date: 2026-10-17
Phase: CI/engineering hygiene audit (FASE B).

## Context

The audit proved three functions unreachable: `trim_leading_spaces` and
`SQL_EXECUTE_ROWS` have no callers anywhere (the multi-row path runs through
`SQL_PREPARE_EXEC_ROWS`), and the legacy `hash_password` hasher is never
called — only its verify branch stays, which old stored hashes still need.
Two review documents still recommended the removed multi-row call.

## Decision

- Delete the three functions. No behaviour change: the build, the full
  suite, and the ASan contract harness all pass unmodified.
- Point `CODING_STANDARDS.md` (rule 9) and `SPEC-user-profile.md` at
  `SQL_PREPARE_EXEC_ROWS` (noting `SQL_PREPARE_EXEC_LOCK` for locking
  reads), and correct the `docs/BUFFER_CONTRACT.md` hasher row.

## Consequences

- Less unaudited surface; the guidance matches the prepared-only reality.
- No count changes (shell 625, gateway 104, full run 729 assertions).
