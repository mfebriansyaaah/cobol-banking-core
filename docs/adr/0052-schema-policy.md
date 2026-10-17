# Schema management policy

Status: accepted
Date: 2026-10-17
Phase: Database schema & migrations audit (FASE D).

## Context

The campaign fixed the mechanics (baseline, diagnostics, seeds) but the
rules lived in PR prose. Operators and future contributors need one place
that says what the source of truth is, what must never be done, and what is
known-benign.

## Decision

- Add `docs/SCHEMA_POLICY.md`: `schema.sql` is the source of truth;
  fold-then-extend on every migration; never re-run `schema.sql` on live
  data; seeds are dev-only and re-runnable; column-order drift is benign by
  construction (no `SELECT *`); migrate needs DDL rights and is fail-stop
  with resume-here semantics.
- Reference it from `docs/STATUS.md`, annotate the README fresh-install
  flow, and refresh the stale `schema.sql` header (it still said 1.7.0 while
  migrations ran to 0029).
- Register the policy doc in `tests/docs_check.sh` like every other doc.

## Consequences

- Schema operations have a written contract; the remaining known
  constraints (no down-migrations, back up before migrating live) are
  stated instead of assumed.
- No count changes (shell 625, gateway 104, full run 729 assertions).
