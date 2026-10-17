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
3. **Migrations run once, in order, fail-stop.** `database/migrate.sh`
   records each version only after success; a failure aborts naming the
   file, and a retry resumes there. `database/migrate.sh --check` gates CI.
   Migrations need DDL rights — run them as the migrate account from
   `database/grants.sh`, never as the DML-only application account.
4. **Seeds are dev-only and re-runnable.** `database/seed_test_data.sql`
   keeps existing fixture rows and resets exactly the two ledger seed rows
   by key. Never apply it to production data.
5. **Column order may drift.** Migrations append columns where convenient;
   `schema.sql` groups them logically. This is benign by construction (no
   positional access) and must not be "fixed" with table rebuilds.

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
