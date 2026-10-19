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
- `database/migrate.sh` applies each not-yet-applied script in order and records
  its name in a `schema_migrations` table only after success.
- `database/migrate.sh --check` exits non-zero if any migration file is unapplied;
  `ci.sh` runs it, so a database missing a migration fails the build.
- `schema.sql` remains the authoritative end state for a fresh database; the
  migrations bring an existing database up to the same state.

## Consequences

- MySQL/MariaDB DDL auto-commits, so migrations must be safe to replay after a
  partial file failure wherever possible. CI statically guards repeatable DDL
  and exercises resume after a simulated partial apply. Explicit exceptions
  are documented in `docs/SCHEMA_POLICY.md`: 0007 is destructive on the live
  post-FX schema; 0011 narrows an ENUM; 0015/0019 rewrite an AUTO_INCREMENT
  primary key. They fail loudly on re-apply without changing state, and require
  schema inspection before an operator re-records the version.
- Adding a schema change means: edit `schema.sql`, add `NNN_*.sql`, bump the
  `schema.sql` header changelog.
- `schema_migrations` is bookkeeping, not domain data; it is created by both
  `schema.sql` and the runner if absent.
