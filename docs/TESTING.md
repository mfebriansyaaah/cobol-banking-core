# Testing: local database setup and safety model

This is the entry point for running the test fleet safely on a developer
machine. It covers the P0-1 safety rails: isolated test databases, least
privilege accounts, the run lock, the restore drill guard, and orphan cleanup.

Related: [Coverage](COVERAGE.md), [Governance](GOVERNANCE.md),
[Contributing](../CONTRIBUTING.md).

## Quickstart (from zero)

```sh
cp tests/.dbenv.example tests/.dbenv
docker compose -f docker-compose.test.yml up -d
scripts/dev/setup-test-db.sh
SKIP_BUILD=1 tests/run_all.sh fast
```

`setup-test-db.sh` waits for the database, provisions the `cobol_app`
(DML-only) and `cobol_migrate` (DDL-capable) accounts, loads
`database/schema.sql`, applies `database/migrations/`, and seeds fixtures.
It is idempotent and refuses to continue when the app account can do DDL.

## Which database do the tests use?

| Setup | `DB_HOST:DB_PORT` | Isolation | Behaviour |
|---|---|---|---|
| Docker Compose + `tests/.dbenv.example` | `127.0.0.1:3307` | automatic | `run_all.sh db` creates `cobol_db_test_<pid>`, runs there, drops it |
| CI (`DB_HOST=127.0.0.1 DB_PORT=3306`, root migrate user) | service MariaDB | `ISOLATED_DB=0` | uses the service database directly (ephemeral) |
| Legacy local MariaDB on `3306` with `cobol_user` | `localhost:3306` | unavailable (no DDL) | **fails closed** unless `ALLOW_DEV_DB=1` |

The fail-closed rule lives in `tests/run_all.sh` (`run_db`): when isolation
is requested (`ISOLATED_DB=1`, the default) against `DB_NAME=cobol_db` and no
DDL-capable migrate user exists, the run exits 1 with setup instructions.
The old behaviour (print `ISOLATION SKIPPED` and continue on the developer
database) is gone. Explicit opt-outs:

- `ISOLATED_DB=0` — run serially against the current database (you own the risk).
- `ALLOW_DEV_DB=1` — acknowledge that the developer database may be modified
  (required when DDL is unavailable). The runner prints a `WARN` and continues.

## The two accounts

`scripts/dev/setup-test-db.sh` provisions:

- `cobol_app` — `SELECT, INSERT, UPDATE, DELETE` only, on `cobol_db` and on
  the throwaway patterns `cobol_db_test_%`, `cobol_db_shard_%`,
  `cobol_db_restore_drill%`. Verified DDL-incapable (`CREATE DATABASE` fails).
- `cobol_migrate` — full privileges (including global `CREATE`/`DROP`), used
  by `database/migrate.sh`, isolation, sharding, and drills.

Suites always run as the app account (`tests/lib/db.sh`). The migrate
credentials are only used for provisioning. This is what makes a SQL bug
unable to `DROP` tables through the test path.

## What the guards refuse

`tests/lib/guard.sh` is the shared safety layer:

- `db_require_safe_target <name>` exits 2 for `cobol_db`, `mysql`,
  `performance_schema`, `sys`, `information_schema`, `cobol_wallet`, and the
  empty string. Throwaway names (`cobol_db_test_*`, `cobol_db_shard_*`,
  `cobol_db_restore_drill*`) pass.
- `db_require_allow_dev_db <reason>` exits 1 unless `ALLOW_DEV_DB=1`.

Covered by `tests/scripts/test_db_guard.sh` (no database needed):

```sh
bash tests/scripts/run.sh
```

## Concurrent runs

`tests/lib/lock.sh` holds an exclusive `flock` per target database
(`DB_HOST:DB_PORT/DB_NAME`) for the whole `run_db` / affected-DB run. A second
runner against the same target exits 1 instead of interleaving `DELETE`/reset
statements. The lock is a kernel lock: it releases when the holder exits, so a
crashed run cannot leave it stale. `flock` is Linux-only; without it the runner
warns and continues (same as before).

## Restore drill

`scripts/ci/restore_drill.sh` rebuilds `schema.sql` + migrations into an
isolated schema and checks the table count. Safety properties (P0-1):

- The target comes **only** from `RESTORE_DRILL_DB` (default
  `cobol_db_restore_drill`). `DB_NAME` is ignored, so exporting
  `DB_NAME=cobol_db` in CI cannot redirect the `DROP` at the database under
  test.
- Protected names are rejected before any `DROP` (exit 2).

Covered by `tests/scripts/test_restore_guard.sh`, which runs the drill offline
against a fake `mysql` and asserts no `DROP` targets `cobol_db`.

## Orphan cleanup

Killed runs can leave `cobol_db_test_*` / `cobol_db_shard_*` databases behind.
`scripts/cleanup-test-dbs.sh` lists them:

```sh
scripts/cleanup-test-dbs.sh                  # dry-run, drops nothing
scripts/cleanup-test-dbs.sh --apply           # drop them
scripts/cleanup-test-dbs.sh --older-than 7    # keep schemas with fresh tables
```

Safety: exact-prefix match only, every candidate re-checked against the
protected-name guard, live PIDs (database name ends in a running PID) skipped,
dry-run by default.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `no DDL rights for isolation; refusing to run` | migrate user cannot `CREATE DATABASE` | `scripts/dev/setup-test-db.sh` (Docker Compose path) |
| `another DB test run holds the lock` | a second `run_all.sh db` targets the same DB | wait, or check `ls /tmp/cobol-db-run-*.lock` |
| `refusing to operate on protected database` | drill/guard target is `cobol_db` or a system DB | set `RESTORE_DRILL_DB` to a throwaway name |
| `cannot list schemata` from cleanup | migrate credentials lack privileges | export `DB_MIGRATE_USER`/`DB_MIGRATE_PASS` for a DDL user |
| port `3307` in use | another Compose project or local forward | `TEST_DB_PORT=3308 docker compose -f docker-compose.test.yml up -d`, then set `DB_PORT=3308` in `tests/.dbenv` |

## Machine-readable reports

Every shell suite records one TSV row in `artifacts/report.tsv`
(`suite`, `status`, `pass`, `fail`, `total`, `duration_ms`, `shard`) via
`tests/lib/report.sh`. Statuses: `pass`, `fail`, or `missing` (exited 0
without a TAP summary; enforced by P0-3). At the end of a run
`artifacts/run-all.json` is generated from the TSV, plus `--json` prints its
path:

```sh
SKIP_BUILD=1 tests/run_all.sh --json fast
node scripts/test-report.mjs --report-dir artifacts --json /tmp/summary.json
node scripts/test-report.mjs --report-dir artifacts --check
```

Gateway suites write JUnit XML next to `run-all.json` when `TEST_REPORT_DIR`
is set (`test:junit`, `test:fast:junit`, `test:gateway:junit`,
`test:endpoints:junit`; `tests/gateway/endpoint_smoke.sh` picks the `:junit`
variant automatically). Conversion and summaries:

- `scripts/tap-to-junit.mjs` — TAP to JUnit (used for shell logs if needed).
- `scripts/ci/summary.mjs` — totals, 10 slowest suites, and failed test names
  to `$GITHUB_STEP_SUMMARY` (stdout locally). CI uploads `artifacts/` always.
- `tests/run_all.sh --no-report` — logs only, no `artifacts/` (same as
  `REPORT_ENABLED=0`).

Unit tests for the converters live in `scripts/test/` and run without a
database: `node --test scripts/test/tap-to-junit.test.mjs
scripts/test/test-report.test.mjs`.

## Files

- `docker-compose.test.yml` — MariaDB 11.8 on `TEST_DB_PORT` (default 3307).
- `scripts/dev/setup-test-db.sh` — provision accounts, schema, migrations, seed.
- `tests/.dbenv.example` — copy to `tests/.dbenv` (gitignored).
- `tests/lib/guard.sh`, `tests/lib/lock.sh` — safety primitives.
- `tests/scripts/` — offline safety tests + `run.sh` harness.
- `scripts/cleanup-test-dbs.sh` — orphan cleanup.
- `scripts/ci/restore_drill.sh` — guarded drill.
