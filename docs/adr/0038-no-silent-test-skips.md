# No silent test skips on lost database seeding

Status: accepted
Date: 2026-10-16
Phase: Test quality & coverage audit (FASE B).

## Context

Twenty gateway tests called `return t.skip(...)` when a database seed failed
(missing mysql client, unreachable database). A skip exits green: `node --test`
reports `fail 0` with the coverage silently gone, and `ci.sh` only gated on the
failure count — so a broken test environment could pass the whole pipeline
while covering nothing.

## Decision

- Add `requireSeed(ok, what)` in `middleware/test/support.js`, which throws a
  descriptive error when a seed prerequisite fails. All twenty skip sites in
  `gateway.test.js`, `endpoints.test.js` and `observability.test.js` now go
  through it, and the now-unused `t` parameters were removed.
- `ci.sh` additionally fails the gateway step when the runner reports any
  skipped test (`ℹ skipped` non-zero), so a future `t.skip` can never pass
  silently either.

## Consequences

- A database outage during tests is a loud failure naming the missing
  prerequisite (verified: bogus `DB_NAME` fails `the list page size is
  bounded` with `test prerequisite failed`, zero skipped), not a quiet green.
- Test count is unchanged (98 gateway tests); only the failure mode changed.
- Shell suites never skipped and needed no change: without the database their
  assertions fail outright.
