# README and gitignore hygiene

Status: accepted
Date: 2026-10-17
Phase: CI/engineering hygiene audit (FASE C).

## Context

Two small rot sources, both verified by execution rather than assumed:

- `.gitignore` listed a root-anchored package-lock pattern that cannot match
  the tracked `middleware/package-lock.json`, plus entries for things that no
  longer exist (ODBC configs retired with ADR-0002, an `interop_test`
  binary, `docs/agents/`).
- The README quick-start ran `CHECK_BALANCE` without the acting owner and
  got `ERROR|FORBIDDEN` (reproduced live); the correct form passes the owner
  as p2. It also named a non-existent `REVOKE_TOKENS` action, omitted
  `/live` and `/ready` from the public routes, described per-request working
  directories without the pool-mode exception, and called `/metrics`
  bearer-gated instead of SUPER_ADMIN-only.

## Decision

- Drop the four stale gitignore entries; keep the real ones (build output,
  `input.txt`/`output.txt`, secrets, `tests/.dbenv`, node_modules, logs).
- Fix the README items above, each verified against the code or a live run
  (`CHECK_BALANCE|sender@test.com|sender@test.com||` returns the seeded
  `USD:1000.00:ACTIVE`).

## Consequences

- New clones get accurate setup docs and an ignore file that matches the
  tree; nothing tracked changes meaning.
- No count changes (shell 625, gateway 104, full run 729 assertions).
