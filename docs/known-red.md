# Known-red / triaged failures

Day 0 preflight 2026-11-04, commit `b6e4d7ce`, MariaDB 11.8.9 on `localhost:3306`
(`cobol_db`, no DDL for `cobol_user`, Docker unavailable).
Full serial run (`ALLOW_DEV_DB=1 ISOLATED_DB=0 DB_SHARDS=1 SKIP_BUILD=1
tests/run_all.sh full`): 273 DB suites, 2 failed. Everything else green
(fast, probes 10/1, integration, gateway fast 387 + gateway 59 with no
residue, skeleton smoke, error harness, fuzz 70 pairs).

Preflight artifacts: `artifacts/preflight-b6e4d7ce/`
(`run-all.json`, `report.tsv`, `last-failed.txt`, `logs/`, `build.log`,
`full.log`).

## Triaged (environment, not product bugs)

| Suite | Owner | Reason | Expiry |
|---|---|---|---|
| `grants_db_tests.sh` (3/6) | @mfebriansyaaah | Local `cobol_db` never provisioned via `scripts/dev/setup-test-db.sh` (no Docker): app and migrate are both `cobol_user` with table DDL, so “app cannot DDL” assertions fail. Needs a fresh 3307 database with `cobol_app` (DML-only) + `cobol_migrate` (DDL). | 2026-12-04 |
| `migration_checksum_db_tests.sh` (4/6) | @mfebriansyaaah | Local `cobol_db` predates migration `0666_schema_migrations_checksum` (`migrate.sh --check` reports it pending, ledger 727 rows vs 657 files). Needs a fresh provisioned database. | 2026-12-04 |

`check_test_counts --strict` on the appended local report also fails for
operational reasons (mixed fast/full rows: table totals 2791 vs 1422; no
gateway JUnit because the full run stopped at the DB gate). Not a product
signal; CI uses one fresh run per job with JUnit. Re-verify on a provisioned
database or in CI.

## Green on this preflight

- fast (gates, build, table 1422, smoke), probes 10 detected / 1 expected miss
- integration (17/17), gateway (fast 387, gateway 59, no residue)
- skeleton smoke, COBOL/C error harness, fuzz (70 pairs, users table intact)
- No orphan `cobol_db_test_*` / `cobol_db_shard_*` databases (none could be
  created — no DDL; verified empty after the run).
