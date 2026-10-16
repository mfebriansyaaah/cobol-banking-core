# Test hygiene: down-path probes, boundary-safe TOTP, self-sufficient fixtures

Status: accepted
Date: 2026-10-16
Phase: Test quality & coverage audit (FASE D).

## Context

The last hygiene gaps from the test-quality audit:

- Only the happy path of `/ready` was tested (200/`ready`/`db:up`); the
  `not_ready`/503 branch — the one that matters in an incident — had no test.
- TOTP helpers minted the current 30s step unconditionally, leaving a
  theoretical boundary race under load.
- The endpoint smoke suite depended on fixed seed-data users
  (`sender@test.com`/`receiver@test.com`), so editing the seed could silently
  change what the suite covers.
- The 30 `check_contains` uses were unaudited substring assertions.

## Decision

- **`/ready` 503**: a gateway test points a fresh app at a bogus `DB_NAME`
  (the spawned COBOL process inherits the test process' environment, so PING
  fails fast) and asserts 503/`not_ready`/`db:down`. Test files run in
  separate processes, so the temporary swap cannot disturb parallel suites.
- **Boundary-safe TOTP**: both TOTP helpers (node and the shell MFA suite)
  mint the next step's code in the last five seconds of a window. The server
  accepts ±1 step, so the codes always verify while the race is gone
  by construction.
- **Self-sufficient fixtures**: the endpoint smoke suite creates its own
  second user and accounts instead of reading seed data; zero fixed-seed
  references remain in `middleware/test/`.
- **`check_contains` audit**: all 30 uses reviewed — each asserts a
  meaningful protocol token or identifier (`SUCCESS|USER_CREATED`,
  `SUCCESS|MFA_SECRET|`, row ids, parties), never a vague fragment, so exact
  matching is impossible (trailing codes/secrets) and unnecessary. No change.

## Consequences

- Gateway suite 98 -> 99 (shell 584 unchanged; full run 683 assertions), with
  the baseline manifest, `docs/STATUS.md` and this ADR updated together.
- The down-path of readiness is now covered behaviour, and the smoke suite is
  immune to seed-data edits.
