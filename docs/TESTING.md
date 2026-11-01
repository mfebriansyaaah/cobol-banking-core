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

## Gateway fixture isolation

Gateway tests share one database, so fixtures are namespaced per file. The
old global cleanups (`DELETE ... LIKE 'gw\_%'`) deleted other suites' users
mid-run, and suites with no cleanup at all (`auth-session`, `observability`)
leaked `obs_*` orphans. Rules:

- Every test-created user goes through
  `uniqueEmail(testNamespace(tag), name)` (`middleware/test/support.js`).
  Namespaces are dash-delimited `<tag>-<stamp>-<rand>` (no `LIKE` escaping
  needed); the stamp is unique per process, file, and rerun — or the shared
  `TEST_RUN_ID` when set (capped so emails fit `users.email(100)`).
- Every file cleans **only** its own namespace in `after()` via
  `cleanupNamespace(NS)`. Never add a global or prefix-wide cleanup that can
  match another file's fixtures. Seed users
  (`sender`/`receiver`/`admin@test.com`) are shared fixtures — never delete
  them.
- `TEST_RUN_ID="t$(date +%s%N)"` gives one run one residue pattern:
  `npm --prefix middleware run test:db`, then
  `TEST_RUN_ID="$TEST_RUN_ID" bash scripts/check_test_residue.sh`.
  `tests/gateway/endpoint_smoke.sh` mints the id for both its parts
  (`test:fast` + `test:gateway`) and fails the run on residue; CI re-runs the
  same check after the full gate and uploads the residue log on failure.
- Split: `test:unit` (pure files, no database) vs `test:db` (DB-backed files,
  serial via `--test-concurrency=1`, file-mode preload; pool-mode coverage
  stays in `test:gateway`). `test`/`test:fast` keep their explicit file lists
  so CI semantics do not change.
- Unit tests: `middleware/test/namespace.test.js` covers the helpers;
  `tests/scripts/test_gateway_residue.sh` covers the gate (fake-`mysql`
  cases plus a live sentinel round-trip that skips offline; runs via
  `bash tests/scripts/run.sh`).
- Troubleshooting: residue on a shared developer database may be from older
  runs — verify against a fresh database (CI does) or delete that run's
  pattern once; never widen a cleanup pattern to make the check pass.

## Schema rebuild drill (and migration idempotency)

`scripts/ci/restore_drill.sh` rebuilds `schema.sql` + migrations into an
isolated schema and checks the table count. It is deliberately called a
*schema rebuild* drill, not a restore: no backup file is involved (a real
backup/restore drill is P1-4). Safety properties (P0-1):

- The target comes **only** from `RESTORE_DRILL_DB` (default
  `cobol_db_restore_drill`). `DB_NAME` is ignored, so exporting
  `DB_NAME=cobol_db` in CI cannot redirect the `DROP` at the database under
  test.
- Protected names are rejected before any `DROP` (exit 2).

Covered by `tests/scripts/test_restore_guard.sh`, which runs the drill offline
against a fake `mysql` and asserts no `DROP` targets `cobol_db`.

`scripts/ci/migration_rollback_drill.sh` is likewise named for what it does:
a *migration apply + idempotency* drill (applies every migration, re-applies
to prove idempotency, verifies the table count, smoke-tests the binary). It
never rolls anything back; a true down-migration rollback drill is P1-4.

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

## Baseline counts are load-bearing

`tests/baseline_counts.txt` records the expected assertion total for every
suite plus the gateway total. `scripts/check_test_counts.mjs` compares the
actual run (`artifacts/report.tsv` + gateway JUnit) against it, and CI runs it
with `--strict` after the full gate. Deleting an assertion — or a whole
suite's assertions — without updating the baseline fails the run instead of
shrinking coverage silently (probe `p7_missing_assertion` in
`tests/probes/` proves the gate fires).

Update the baseline only for an intentional count change, and only with
`--write` (never hand-edit numbers):

```sh
# After running the affected suites (full run for DB changes):
node scripts/check_test_counts.mjs --report-dir artifacts --write
git diff -- tests/baseline_counts.txt   # review every hunk
```

```sh
# Table-case-only change (no DB run needed):
node scripts/check_test_counts.mjs --static . --write
```

Rules:

- One line per intentional change, with reason. PR description must carry:
  `Alasan:`, `Sebelum:` (old total), `Sesudah:` (new total), `Verifikasi:`
  (command + result).
- Never lower a number to make CI green. If the count dropped, the test was
  lost — restore it.
- The gate fails in both directions: a suite/count with no baseline entry
  (`unlisted`) and a baseline entry with no data (`missing`, strict mode) both
  fail. Removing a suite requires removing its line in the same PR.
- Exceptions, all documented in `scripts/check_test_counts.mjs`:
  - `db_schema_tests` is loop-generated (19 `assert_match` lines execute 76
    assertions). Static mode checks only presence; the exact total is
    enforced at runtime and `--write --static` never touches it.
  - `gateway_tests` has no static count (tests are generated dynamically);
    it is enforced at runtime from JUnit XML.
  - `smoke` is recorded but not count-gated (1-assertion liveness check;
    its failure already fails the run).
- A count change without a suite/test change is suspicious — the gate treats
  it as drift until `--write` is run and the diff is reviewed.

## Cross-layer contract: route reachability + field order

DB suites invoke the COBOL binary directly, so two cross-layer failure modes
were invisible: a route that is defined but never mounted (404 at runtime),
and a route whose `fields` order drifts from the COBOL `LS-PARAM` order
(executes with swapped parameters). Two mechanisms close this:

**Reachability** (`middleware/test/route-reachability.test.js`, part of
`test:fast`). Iterates all 5427 `ROUTES`: guarded routes are hit without a
token (must 401/403 before any COBOL runs — a 200/400 would mean auth was
skipped), public routes are hit with `{}` (must fail validation — a 401/403
would mean auth was wrongly added). No request in this suite can write:
nothing carries a token or passes validation. `/health` and `/ready` are
covered explicitly (they are not in `ROUTES`).

**Field order** (`scripts/check_field_order.mjs` in the static gates,
`scripts/generate_field_order.mjs` for regeneration,
`tests/contracts/route_field_order.json` as the reviewed snapshot).
Every route is keyed `file :: METHOD path` with its action and positional
field tokens; shared constants (`DATE_RANGE`) are expanded so drift inside
them is visible; the 65 `app.js` routes that declare fewer than 6 fields are
recorded as-is (trailing blanks implied, tolerated by COBOL). Any
added/removed/changed route or field order fails the gate until the snapshot
is regenerated **and the diff is reviewed** — the snapshot prevents drift, it
does not prove the order is semantically right. The hand-reviewed 17-action
golden contract in `middleware/test/fixtures/field_order_contract.json`
remains the semantic core. Probe `p8_field_order_drift` proves the gate fires.

When adding or changing a route: implement, run
`node scripts/generate_field_order.mjs --write .`, review every hunk of the
snapshot diff, and explain it in the PR. Never regenerate blindly to make CI
green. If the order change is a behavior change (not just naming), update the
domain's DB suite to assert the new mapping.

## Action coverage ratchet: every routed action must be shell-executed

`scripts/check_action_test_coverage.mjs` (static gates, probes) parses every
gateway action from `middleware/src/routes/*.js` + `app.js` and requires
each to be *invoked* by a shell-level test: a literal
`run_cobol "ACTION|..."` in `tests/db/*.sh` or `tests/integration/*.sh`, or a
`name@@expected@@ACTION|...` line in `tests/cobol/cases/*.cases`. Dynamic
invocations don't count. Actions with no shell coverage must be recorded in
`tests/action_test_coverage_baseline.txt`, or the gate fails. The gate also
fails on *stale* entries (a test was added but the entry left behind) and
*dead* entries (the route is gone).

HTTP tests do **not** count: hitting a route over HTTP is not executing its
COBOL action (a guarded route 401s before the binary runs; an invalid payload
400s before it runs). The current picture (generated 2026-11-01, 5399 route
actions): 4338 shell-covered (80.3%), 1061 baselined in four verified groups
— 502 template `*_UPDATE` (no template suite invokes UPDATE, so
optimistic-locking paths are unproven), 63 inline `app.js` routes
(HTTP-exercised, no shell invocation), 479 in route files with no DB suite,
17 richer-surface actions whose suites don't invoke them.

Workflow: add the shell test first (then the baseline entry becomes stale and
the gate tells you to remove it), or run with `--write` and move the new
actions under a category header with a documented reason:

```sh
node scripts/check_action_test_coverage.mjs --write
git diff -- tests/action_test_coverage_baseline.txt   # categorize + justify
```

Rules: never add an entry to make CI green without a reason; never remove an
entry for an action that is still untested. Probe `p9_action_without_test`
(a `run_cobol` call replaced by a canned SUCCESS string, suite still green)
proves only this gate notices. Unit tests live in
`scripts/test/check_action_test_coverage.test.mjs` (fixture trees, no DB).

## Files

- `docker-compose.test.yml` — MariaDB 11.8 on `TEST_DB_PORT` (default 3307).
- `scripts/dev/setup-test-db.sh` — provision accounts, schema, migrations, seed.
- `tests/.dbenv.example` — copy to `tests/.dbenv` (gitignored).
- `tests/lib/guard.sh`, `tests/lib/lock.sh` — safety primitives.
- `tests/scripts/` — offline safety tests + `run.sh` harness.
- `scripts/check_test_residue.sh` — fails a gateway run that leaves user fixtures behind.
- `scripts/cleanup-test-dbs.sh` — orphan cleanup.
- `scripts/ci/restore_drill.sh` — guarded drill.
