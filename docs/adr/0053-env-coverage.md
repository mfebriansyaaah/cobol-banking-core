# Machine-checked env documentation coverage

Status: accepted
Date: 2026-10-17
Phase: CI/engineering hygiene audit (FASE A).

## Context

Four gateway knobs (`JWT_ISSUER`, `JWT_AUDIENCE`, `MFA_ISSUER`,
`REFRESH_TTL_DAYS`) and three core knobs (`TRANSFER_MAX_PER_TXN`,
`TRANSFER_DAILY_LIMIT`, `PENDING_RETENTION_DAYS`) were read with compiled-in
defaults but absent from `middleware/.env.example` — operators could not
discover them, and the gap only grows as new knobs are added.

## Decision

- Document every knob with its default in `middleware/.env.example`
  (grouped: tokens, refresh families, MFA issuer, transfer/retention limits).
- Add `tests/env_check.sh`, run as its own `ci.sh` step: every
  `process.env.X` default read by the gateway and every `env_or` setting
  read by the COBOL core must have an active `KEY=` line in the example.
  A commented-out key does not count. Verified both directions (passes on
  the fixed tree, names the variable when one is dropped).
- Reference the guarantee from `docs/STATUS.md`.

## Consequences

- New configuration always ships documented, or CI fails naming the knob.
- No count changes (shell 625, gateway 104, full run 729 assertions).
