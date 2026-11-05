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
| --- | --- | --- | --- |
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

## CI scale: shard matrix, cache, nightly

DB suites run two ways from the same code (`tests/run_all.sh`):

- Local / single job: `run_all.sh db` shards in-job (`DB_SHARDS` workers,
  default 4) against throwaway worker databases.
- CI: four `db-shards` matrix jobs (`matrix.shard` 0–3) each run
  `run_all.sh db-shard` with `DB_SHARD_INDEX`/`DB_SHARD_COUNT`, so every
  shard gets its own runner and database. `db-aggregate` then merges the
  per-shard `report.tsv` files, verifies each shard ran exactly its planner
  slice (missing/duplicated/moved suites fail the gate), checks the
  fleet-wide inventory, and only then runs the assertion-count gate and the
  test summary — so `--strict` sees the complete picture.

`tests/run_all.sh full` in CI sets `SKIP_DB=1` (the matrix covers the DB
fleet; local `full` always runs it). This is CI-only plumbing, not a general
flag.

Planner weights (`scripts/shard_suites.mjs`, LPT scheduling) come from
`--timings artifacts/latest/run-all.json` (measured durations, median fallback)
or, without it, from baseline assertion counts. Assignment is deterministic
for identical inputs; `scripts/test/shard_suites.test.mjs` pins that.

`coverage-pr` restores `cobol/build` from cache (key pins GnuCOBOL 3.2 plus
every build input) so `./build.sh` inside coverage is a warm relink; the
`build` job is deliberately not cached (apt GnuCOBOL 3.1.2 — objects must
never cross compiler versions; its binary travels via artifact).

Nightly (`nightly.yml`, own concurrency group so pushes never cancel it)
runs the full gate twice and fails on any per-suite drift between the two
reports (`scripts/ci/compare_runs.mjs` ignores durations), then runs the
drills, gateway coverage, the performance benchmark, and the gateway load
test. A red nightly means order-dependence or a flake,
not a broken PR.

Push to `main` (and manual `workflow_dispatch`) additionally runs the
`db-ops` job — migration rollback drill, backup/restore drill, and schema
drift check — exactly once per push and once nightly. PRs skip it; the PR
`test` job keeps the static gates, table, smoke, integration, error harness,
gateway, and residue checks.

On any failure, `scripts/ci/collect_diagnostics.sh` gathers tool versions,
git state, DB/table counts, the ledger check, and log tails into one
directory (best-effort, never prints secrets) uploaded as an artifact.

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

`scripts/ci/migration_rollback_drill.sh` is a true snapshot-based rollback:
it applies migrations up to N-1 into `ROLLBACK_DRILL_DB`, snapshots it, applies
N, restores the snapshot, and verifies the ledger and a marker row are back at
N-1 (with `migrate.sh --check` reporting exactly N pending). The old
apply-twice idempotency check never proved anything could go backward.

`scripts/ci/backup_restore_drill.sh` is a logical backup drill with data
verification: it dumps `DB_NAME`, restores into `RESTORE_DRILL_DB`, and
compares every table's row count plus `CHECKSUM TABLE` on key tables, then runs
`migrate.sh --check` on the restored copy. Both drills take their target only
from env (`ROLLBACK_DRILL_DB` / `RESTORE_DRILL_DB`, never `DB_NAME`) and
refuse protected names before any `DROP`.

`scripts/check_schema_drift.sh` fails when `schema.sql` + migrations no longer
reproduce the committed `database/schema_full.sql` (regenerate deliberately
with `scripts/generate_schema_snapshot.sh` after reviewing the diff).

`scripts/ci/restore_drill.sh` remains for local use: a schema-only rebuild
(no backup file, no data verification), covered by
`tests/scripts/test_restore_guard.sh`.

## Migrated DB snapshot producer (CI-008A)

`scripts/ci/build_db_snapshot.sh <output.sql.gz>` dumps an already-migrated
database into a gzip snapshot for the per-run `db-snapshot` CI artifact. The
CI job loads `database/schema.sql`, applies `database/migrate.sh`, and dumps
before any fixture seeding, so the snapshot is a migrated baseline with
reference data only (no test fixture users). Safety properties:

- Read-only: no `DROP` or `CREATE` anywhere; only `migrate.sh --check`,
  `mysqldump`, and a table-count query.
- Refuses system databases (`mysql`, `performance_schema`, `sys`,
  `information_schema`) and empty/missing credentials (exit 2).
  `cobol_db` is allowed as the dump source — dumping is read-only.
- Fails when `migrate.sh --check` reports pending migrations, when the dump
  is empty, or when the source has no tables.
- Dump flags are the D5 default (`--single-transaction --routines --triggers`);
  `--no-tablespaces` is omitted (see `docs/CI.md`).

Covered by `tests/scripts/test_db_snapshot_guard.sh`, which runs the producer
offline against fake `mysql`/`mysqldump`/`migrate.sh` and pins the refusals,
the `--check` gate, the output report, and the flag set. Restoring the
snapshot in DB jobs (including the restore-before-`grants.sh` order) belongs
to CI-008B and is intentionally not done here.

## Orphan cleanup

A successful `tests/run_all.sh full` leaves no throwaway database behind: one
top-level EXIT trap owns `cleanup_db_resources` for the whole run, and phase
functions never reset the recorded lists (`tests/scripts/test_db_cleanup.sh`
guards this). Killed runs can still leave `cobol_db_test_*` /
`cobol_db_shard_*` databases behind. `scripts/cleanup-test-dbs.sh` lists them:

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
| --- | --- | --- |
| `no DDL rights for isolation; refusing to run` | migrate user cannot `CREATE DATABASE` | `scripts/dev/setup-test-db.sh` (Docker Compose path) |
| `another DB test run holds the lock` | a second `run_all.sh db` targets the same DB | wait, or check `ls /tmp/cobol-db-run-*.lock` |
| `refusing to operate on protected database` | drill/guard target is `cobol_db` or a system DB | set `RESTORE_DRILL_DB` to a throwaway name |
| `cannot list schemata` from cleanup | migrate credentials lack privileges | export `DB_MIGRATE_USER`/`DB_MIGRATE_PASS` for a DDL user |
| port `3307` in use | another Compose project or local forward | `TEST_DB_PORT=3308 docker compose -f docker-compose.test.yml up -d`, then set `DB_PORT=3308` in `tests/.dbenv` |

## Test runner CLI and ergonomics

`tests/run_all.sh --help` is the reference; the useful core:

- `--only <substr>` runs only DB suites whose file name contains it
  (`--only loan`). Combine with `--repeat N` to flake-hunt:
  `run_all.sh db --only loan --repeat 5` runs each match five times and
  counts every iteration, so one flaky pass still fails the suite.
- `--failed` reruns exactly the suites listed in
  `artifacts/latest/last-failed.txt` (rewritten by every run; a green run
  clears it). When a full run goes red overnight, `--failed` reproduces it in
  seconds instead of rerunning 500+ suites.
- `--keep-logs` copies per-suite logs to timestamped
  `tests/artifacts/logs-*` (gitignored) for forensics.
- `--mode` duplicates the positional mode; `--no-build` skips the COBOL
  build; `--allow-dev-db` acknowledges the developer database may be
  modified (required without DDL rights — see below).
- `db-shard` runs one matrix shard:
  `DB_SHARD_INDEX=0 DB_SHARD_COUNT=4 run_all.sh db-shard`.

Every test that invokes the COBOL binary directly runs in a throwaway
workdir (`tests/lib/workdir.sh`), never the repo root: the binary reads
`./input.txt` and writes `./output.txt`, so sharing the checkout would
interleave suites and litter `input.txt`/`output.txt` everywhere.

`make` wraps the common flows (`make bootstrap`, `make db-up`,
`make test-fast`, `make test-db`, `make test-full`, `make lint`,
`make coverage`); `scripts/dev/bootstrap.sh` is the zero-to-green path
(dependency check, Compose DB, provision, build, fast suite) and
`.devcontainer/` reproduces the same toolchain in a codespace.

## Machine-readable reports

Every invocation gets its own run directory —
`artifacts/runs/<UTC-timestamp>-<pid>/` — with `report.tsv`, `run-all.json`,
`last-failed.txt`, `build.log`, `logs/`, `junit/gateway/`, and `junit/db/`
(converted from TAP logs). `artifacts/latest` is a symlink to the newest run.
An explicit `REPORT_DIR` (CI jobs, nightly runs, `--report-dir` callers) is
used as-is instead. Repeated runs can never contaminate each other; pointing a
tool at a stale `artifacts/report.tsv` path fails closed — use
`artifacts/latest/` or a specific `runs/<id>/` directory.

Every shell suite records one TSV row in the run's `report.tsv`
(`suite`, `status`, `pass`, `fail`, `total`, `duration_ms`, `shard`) via
`tests/lib/report.sh`. Statuses: `pass`, `fail`, or `missing` (exited 0
without a TAP summary; enforced by P0-3). At the end of a run
`run-all.json` is generated from the TSV, plus `--json` prints its
path:

```sh
SKIP_BUILD=1 tests/run_all.sh --json fast
node scripts/test-report.mjs --report-dir artifacts/latest --json /tmp/summary.json
node scripts/test-report.mjs --report-dir artifacts/latest --check
```

Gateway suites write JUnit XML to the run's `junit/gateway/` when
`TEST_REPORT_DIR` is set (`test:junit`, `test:fast:junit`, `test:gateway:junit`,
`test:endpoints:junit`; `tests/gateway/endpoint_smoke.sh` picks the `:junit`
variant automatically; `tests/run_all.sh` sets the directory). Conversion and summaries:

- `scripts/tap-to-junit.mjs` — TAP to JUnit (used for shell logs if needed).
- `scripts/ci/summary.mjs` — totals, 10 slowest suites, and failed test names
  to `$GITHUB_STEP_SUMMARY` (stdout locally). CI uploads `artifacts/` always.
- `tests/run_all.sh --no-report` — logs only, no `artifacts/` (same as
  `REPORT_ENABLED=0`).

Unit tests for gates and scripts live in `scripts/test/` and run without a
database or a build: `npm run test:scripts` (equivalently
`bash scripts/test/run.sh`; CI runs them in the lint job and uploads
`test-results/gate/junit.xml`).

Conventions for adding gate tests:

- Prefer a unit test over a detection probe or a full-suite run whenever the
  subject is deterministic without infrastructure. Probes
  (`tests/probes/`, which fail the run) guard against gate blindness;
  full suites guard end-to-end behaviour. Unit tests pin exact behaviour:
  given inputs X, the gate must select/report Y.
- Keep fixtures hermetic: build a temp repo from
  `tests/fixtures/script-trees/mini` via `scripts/test/helpers.mjs`
  (`makeFixtureRoot`/`cleanupFixture`) and pass the fixture root to the
  script under test (`--root`, `--files`). Never point a gate at the real
  repo in a unit test, and never write outside the temp dir — the shared
  `tests/fixtures` tree is committed and must stay pristine (run.sh has no
  network, DB, or build access by design).
- One assertion theme per `test()` block; assert stderr/stdout text, exit
  codes, and (for JSON outputs) parsed structure, not formatting.
- New gate scripts ship with `scripts/test/<name>.test.js` in the same PR;
  CI's `npm run test:scripts` picks them up automatically.

## Baseline counts are load-bearing

`tests/baseline_counts.txt` records the expected assertion total for every
suite plus the gateway total. `scripts/check_test_counts.mjs` compares the
actual run (a run's `report.tsv` + its `junit/gateway/` JUnit) against it,
and CI runs it with `--strict` after the full gate. Deleting an assertion — or a whole
suite's assertions — without updating the baseline fails the run instead of
shrinking coverage silently (probe `p7_missing_assertion` in
`tests/probes/` proves the gate fires).

Update the baseline only for an intentional count change, and only with
`--write` (never hand-edit numbers):

```sh
# After running the affected suites (full run for DB changes):
node scripts/check_test_counts.mjs --report-dir artifacts/latest --write
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
`test:fast`). Iterates all 2801 `ROUTES` (2026-11-04; see `docs/STATUS.md`): guarded routes are hit without a
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
400s before it runs). The current picture (measured 2026-11-05, 527 route
actions per `node scripts/check_action_test_coverage.mjs .`): 527
shell-covered (100.0%), 0 baselined (see
`tests/action_test_coverage_baseline.txt` for the live numbers; do not treat
this paragraph as the source of truth).

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

## Local lint and security gates

CI runs a `lint` job with no services; run the same commands locally before
pushing. Tool versions are pinned (install commands in the job) because linter
output drifts between releases.

```sh
bash scripts/ci/lint.sh        # shellcheck -x (all shell) + shfmt -i 4 (allowlist)
npm run lint                   # eslint: gateway + scripts
npm run format:check           # prettier: scripts + root configs only
npm run lint:md                # markdownlint (docs; see ignores below)
actionlint                     # workflow correctness (also runs shellcheck inside run: blocks)
yamllint --strict -c .yamllint .github/workflows/ docker-compose.test.yml monitoring/prometheus-alerts.yml .github/ISSUE_TEMPLATE/config.yml
promtool check rules monitoring/prometheus-alerts.yml
semgrep --config .semgrep/rules.yml --exclude node_modules --exclude package-lock.json --error middleware scripts
gitleaks detect --source . --no-git --config .gitleaks.toml
bash scripts/ci/c_strict.sh    # gcc -Werror syntax check + cppcheck over cobol/c_lib
npm audit --omit=dev && npm --prefix middleware audit --omit=dev
```

Rules of the road:

- Fix real findings; suppress only false positives, always with a reason
  comment (`# shellcheck disable=SC...` with why, `// eslint-disable-next-line`
  with why). A bare disable without a reason fails review.
- `shfmt` and `prettier` enforce an allowlist, not the whole tree: the
  `scripts/` toolchain is formatted, historical domain suites and gateway
  sources are grandfathered (formatting 500+ files is churn without safety
  value; ESLint already gates the real issues there). New toolchain files go
  on the allowlist formatted; `scripts/ci/lint.sh` documents the split.
- `markdownlint` ignores generated output (`docs/data_dictionary.md`,
  `docs/MODULE_INDEX.md`) and immutable history (`docs/adr/`, see
  `.markdownlintignore`); line length is 120 to match `.prettierrc`, tables
  and code blocks are exempt.
- `semgrep` only scans git-tracked files: `git add` new files before
  trusting a local run; CI always scans the committed tree.
- `gitleaks` scans the worktree (`--no-git`): allowlist entries in
  `.gitleaks.toml` are narrow path+pattern pairs with a justification (e.g.
  the seeded migration checksums, which are hashes of public files).
- `npm audit` fails the gate on any reported severity; fix via lockfile bump
  (`npm audit fix` in the owning package, then re-run its tests — run
  `npm ci`, never `--omit=dev` installs, or dev dependencies get pruned).

## Files

- `docker-compose.test.yml` — MariaDB 11.8 on `TEST_DB_PORT` (default 3307).
- `scripts/dev/setup-test-db.sh` — provision accounts, schema, migrations, seed.
- `tests/.dbenv.example` — copy to `tests/.dbenv` (gitignored).
- `tests/lib/guard.sh`, `tests/lib/lock.sh` — safety primitives.
- `tests/perf/bench.sh` + `load_gateway.sh` + `baseline.json` — latency budgets and gateway load; see `tests/perf/README.md`.
- `tests/scripts/` — offline safety tests + `run.sh` harness.
- `scripts/check_test_residue.sh` — fails a gateway run that leaves user fixtures behind.
- `scripts/ci/aggregate_shard_reports.sh` + `db-shards`/`db-aggregate` jobs — sharded DB fleet with merged verification.
- `tests/lib/workdir.sh` + `Makefile` + `scripts/dev/bootstrap.sh` + `.devcontainer/` — runner ergonomics.
- `tests/README.md` — fleet layout, slice recipes, and how to add a test.
- `scripts/shard_suites.mjs` + `scripts/test/shard_suites.test.mjs` — deterministic LPT shard planner.
- `scripts/ci/compare_runs.mjs` + `nightly.yml` — twice-run flake gate.
- `scripts/ci/collect_diagnostics.sh` — failure forensics bundle.
- `scripts/cleanup-test-dbs.sh` — orphan cleanup.
- `scripts/ci/restore_drill.sh` — guarded drill.
