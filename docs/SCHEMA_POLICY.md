# Schema management policy

How the database shape is owned, changed, and verified. The running code
only ever uses named columns (`SELECT` lists and `INSERT` column lists
everywhere; no `SELECT *`), so column order is free to drift.

## Source of truth

`database/schema.sql` is the full current state: every table, index,
trigger, check, and seed-adjacent constant that a fresh install needs.
`database/migrations/NNN_*.sql` move *existing* databases forward.
Both paths must converge to the same shape (verified by audit diffing
`information_schema` against `schema.sql`).

## Rules

1. **Fold then extend.** Adding a migration means folding its objects into
   `database/schema.sql` AND extending the baseline block
   (`INSERT INTO schema_migrations ...`) in the same change.
   `tests/test_migrate.sh` fails when the baseline versions differ from the
   migration files.
2. **Never re-run `schema.sql` on a live database.** It contains
   `DROP TABLE IF EXISTS ledger` and non-idempotent `CREATE INDEX`
   statements: it is a fresh-install baseline, not a migration tool. Live
   databases move forward only via `database/migrate.sh`.
3. **Migrations run in order and fail-stop; retries are explicit.**
   `database/migrate.sh` records each version only after the whole file
   succeeds and aborts naming a failed file. Because MySQL/MariaDB DDL
   auto-commits, a retry replays the file: every ordinary statement must be
   safe to re-run (guarded DDL, idempotent seeds, scoped updates). CI checks
   this contract and tests resume after a simulated partial apply.
   **Documented exceptions:** 0007 drops schema objects and must not be
   replayed on the post-FX live schema; 0011 narrows an ENUM and can refuse
   re-application when newer enum values are present; 0015 and 0019 rewrite
   the primary key around an AUTO_INCREMENT column and fail at parse time on
   re-run. These failures do not imply the original migration was rolled
   back. Inspect `information_schema` and migration effects before recovery;
   only re-record a version after confirming its complete intended state.
   `database/migrate.sh --check` gates CI. `database/migrate.sh --only <version>`
applies exactly one file (used by the replay test so it does not scan every
migration per iteration). Migrations need DDL rights — run
   them as the migrate account from `database/grants.sh`, never as the
   DML-only application account.
4. **Seeds are dev-only and re-runnable.** `database/seed_test_data.sql`
   keeps existing fixture rows and resets exactly the two ledger seed rows
   by key. Never apply it to production data.
5. **Column order may drift.** Migrations append columns where convenient;
   `schema.sql` groups them logically. This is benign by construction (no
   positional access) and must not be "fixed" with table rebuilds.

## Reference-data tables (lab artifact, 2026-10)

Migrations 0047 through 0052 create 211 `ref_*` tables from
`data/entities.json` and fold them into `database/schema.sql`. They are a
volume-sprint artifact, not a production data model. New production reference
data must use the generic model in `docs/PRODUCTION_GRADE_PLAN.md`
(`ref_type`, `ref_value`, versioning, translations, hierarchy, audit), not the
entity generator. Until the consolidation in Phase 2, the fold-then-extend rule
still applies to every new migration, and no new generated `ref_*` table may be
added to production scope.

## Reference-data cutover (2026-10)

Migration 0054 copies the country and holiday reference data into the generic
engine. The legacy `ref_country` and `ref_holiday` tables remain as a read-only
safety copy for one release. New production reference data must use
`ref_type`/`ref_value`/`ref_value_version`; a later cleanup migration may drop
the legacy tables after the safety window.

## Fresh install

```sh
mysql -u root -e "CREATE DATABASE IF NOT EXISTS cobol_db;"
mysql cobol_db < database/schema.sql
mysql cobol_db < database/seed_test_data.sql
database/migrate.sh            # baseline: reports "no pending migrations"
./build.sh
```

## Operational notes

- Back up before migrating a live database; there is no down-migration.
- The ledger and audit trail are append-only by trigger; deletes cascade
  into the immutable `*_archive` tables via pre-delete triggers.
- `users.email` renames cascade (`ON UPDATE CASCADE`); related FKs follow.
