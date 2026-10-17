# Migration baseline in schema.sql

Status: accepted
Date: 2026-10-17
Phase: Database schema & migrations audit (FASE A).

## Context

Two related defects, both proven against `information_schema`:

- `schema.sql` already reflects the post-migration state, yet `migrate.sh`
  replayed all 28 migrations on a fresh database — where `DROP COLUMN` of
  never-existing columns (0007) and duplicate `ADD COLUMN`s abort the run
  under `set -e`. The README fresh-install path was unexecutable.
- Drift between the two paths: `idx_exchange_lookup` shipped in
  `schema.sql` but migration 0008 re-created `exchange_rates` without it, so
  migrated databases lacked an index fresh installs had (a full
  schema-vs-live diff found this as the single index drift).

## Decision

- `schema.sql` now pre-records every migration whose effects it folds in (the
  baseline block, 0001-0029), so `migrate.sh` on a fresh database applies
  only strictly newer migrations. Policy going forward: adding a migration
  means folding its objects into `schema.sql` AND extending the baseline —
  `tests/test_migrate.sh` fails when the listed versions differ from the
  migration files.
- Migration 0029 restores `idx_exchange_lookup` on migrated databases,
  converging them back to the schema baseline (the pair is also covered by
  `unique_pair`, so the gap was consistency, not a missing access path).
- Coverage: `tests/test_migrate.sh` 8 -> 11 (baseline equality, FX index
  present, no orphan `schema_migrations` records).

## Consequences

- Fresh installs work again (schema + seeds + migrate-to-green), and the two
  schema paths cannot silently diverge: any new migration forces a
  `schema.sql` update in the same change.
- Deliberately unchanged: column-order drift between the paths (harmless —
  no `SELECT *` anywhere), non-idempotent seeds and non-rerunnable
  `schema.sql` (documented operational constraints, later phases).
- Shell 614 -> 617, gateway 104 unchanged; full run 721 assertions.
