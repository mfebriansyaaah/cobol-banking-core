# Tests

This directory holds the whole verification fleet. For the safety model
(isolation, accounts, locks) and the CI mapping, start with
[TESTING.md](../docs/TESTING.md).

## Layout

- `run_all.sh` — the unified runner. Modes: `fast db db-shard full probes
  affected integration` (default `full`). Run `./tests/run_all.sh --help`
  for the flag list.
- `db/*_db_tests.sh` — one DB domain suite per file (537 files). Each is
  self-contained: it resets its own tables, seeds idempotently, and records
  TAP plus one `report.tsv` row. New suites must end in `_db_tests.sh` and
  get a `db_<name>_tests` line in `tests/baseline_counts.txt` (see below).
- `gateway/endpoint_smoke.sh` — runs the middleware suites (`test:fast` +
  `test:gateway`) and fails the run on leftover fixtures.
- `scripts/` — offline harness tests (`test_*.sh`, run via `run.sh`):
  guard restores, residue gate, schema-drift fixture, runner CLI.
- `cobol/` — table-driven COBOL cases (`cases/*.cases`) plus the skeleton
  smoke test.
- `fuzz/` — malformed-input fuzz over gateway actions.
- `perf/` — latency benchmarks (not a gate).
- `integration/` — cross-domain flows (loan → collection → payment → GL).
- `lib/` — shared shell libraries (`db.sh`, `guard.sh`, `lock.sh`,
  `report.sh`, `workdir.sh`, `cobol.sh`). Suites source these; never copy
  their logic into a suite.
- `contracts/` — cross-layer contracts (`route_field_order.json`).

## Running a slice

```sh
tests/run_all.sh --help                    # all flags and modes
tests/run_all.sh db --only loan            # only suites matching "loan"
tests/run_all.sh db --repeat 3             # every selected suite 3x (flake hunt)
tests/run_all.sh db --failed               # only suites from last-failed.txt
DB_SHARD_INDEX=0 DB_SHARD_COUNT=4 tests/run_all.sh db-shard   # one matrix shard
bash tests/scripts/run.sh                   # offline harness tests
```

`--failed` reads `artifacts/last-failed.txt`, rewritten by every run (a green
run clears it). `--repeat` counts every iteration as its own report row, so a
single flaky pass still fails the suite. `--keep-logs` copies per-suite logs
to `tests/artifacts/` (gitignored).

## Adding a test

- DB domain: new `tests/db/<domain>_db_tests.sh` following an existing suite
  (source `lib/db.sh`, `require_db`, reset-then-seed, `assert_match`,
  `print_summary`, exit non-zero on failure). Add its count with
  `node scripts/check_test_counts.mjs --report-dir artifacts --write` and
  review the `baseline_counts.txt` diff — never hand-edit numbers.
- Never touch another suite's fixtures: test users live in per-file
  namespaces (see `middleware/test/support.js`), throwaway databases are per
  run, and the app account cannot DDL.

## Debugging a failure

- Per-suite logs: `artifacts/logs/<suite>.log` (or `tests/artifacts/` with
  `--keep-logs`).
- Rerun exactly it: `tests/run_all.sh db --only <substring>`.
- Flaky suspect: `--repeat 5` on the suite, then compare `report.tsv` rows.
- Machine-readable totals: `artifacts/run-all.json`
  (`node scripts/test-report.mjs --report-dir artifacts --check`).
