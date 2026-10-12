# Versioned schema migrations with a tracking table

Status: accepted
Date: 2026-10-11
Phase: migrations tooling.

## Context

The schema evolves (new tables, FK behaviour), but changes were applied to a
database by hand: `schema.sql` describes the end state and `database/migrations/`
holds incremental scripts, with nothing recording which scripts a given database
had run. Environments could silently drift.

## Decision

- Every schema change ships as an ordered script `database/migrations/NNN_*.sql`.
- `database/migrate.sh` applies each not-yet-applied script once and records its
  name in a `schema_migrations` table; re-running is a no-op.
- `database/migrate.sh --check` exits non-zero if any migration file is unapplied;
  `ci.sh` runs it, so a database missing a migration fails the build.
- `schema.sql` remains the authoritative end state for a fresh database; the
  migrations bring an existing database up to the same state.

## Consequences

- Migrations must be idempotent or apply cleanly exactly once (the runner records
  them, so a script that errors is not recorded and will be retried).
- Adding a schema change means: edit `schema.sql`, add `NNN_*.sql`, bump the
  `schema.sql` header changelog.
- `schema_migrations` is bookkeeping, not domain data; it is created by both
  `schema.sql` and the runner if absent.
