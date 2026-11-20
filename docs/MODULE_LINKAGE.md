# Module Linkage

## Purpose

Linkage level is the only module classification. It measures whether a module
is actually tied to the core business domain, from evidence in code and tests.

## Levels

| Level | Meaning |
| --- | --- |
| L3 | Core-linked: money-table touch with depth and a DB/table/integration test, or a module listed in `coreModules` |
| L2 | Business-linked: business-table reference, call into a core module, or money-action literal, plus a DB/table/integration test |
| L1 | Weak/untested link: reference-only (`users`/`currencies`/`ref_*`, incl. the `ALLOW-ADMIN` role lookup) or linked code with no test |
| L0 | No core linkage: own generic tables only, or no table references at all |
| UTILITY | Pure helper (`hashlen_core`, `ref_engine`, `ref_ext_core`); never a retire candidate |

## Core anchors

`manifest/linkage.json` `coreModules` is the anchor list of authoritative
business modules. Membership means L3. Changes require maintainer review.

## Statuses

`ACTIVE`, `PILOT`, `REVIEW`, `FROZEN`, `RETIRED` remain in
`manifest/domain_status.json`. Status is disposition, not classification:
it records review state, not business importance.

## Quality gates

- L3 coverage floor 70% (`scripts/check_coverage_modules.mjs --floor 70`).
- 0 warnings (`tests/warning_baseline.txt`).
- DB/integration test for L2+ (`tests/db/*_db_tests.sh` or `tests/integration/`).
- Clone budget (`scripts/check_clone_budget.mjs`).
- Integration completion (`scripts/check_integration_completion.mjs`).

## How to add a module

Create COBOL + route + DB suite; add to `manifest/linkage.json` only if it
is a core anchor; run `build_linkage_graph`, `classify_domains --sync-linkage`,
`build_module_quality`, and the gates.

## How to change linkage

Add a business table to `linkage.json`, add a core CALL, or add a money
action; rebuild the graph; never hand-edit `manifest/linkage_graph.json`.

## What not to do

No new clones, no generator, no hand-edited baselines, no lowering
coverage/warning baselines.

Rules:

- The `ALLOW-ADMIN` role lookup (`SELECT role FROM users WHERE email = ?`)
  and audit actor fields are **not** linkage.
- New modules/routes need L2+ linkage (or `UTILITY`/`INFRA` status); L0/L1 is rejected.
- L0/L1 is refactored never, retired eventually (`tests/linkage_baseline.txt`
  is the ratchet; `scripts/check_linkage.mjs` enforces it in `run_all.sh fast`).

## Intentional exceptions

- `dashboard_core`: read-only/aggregation, no `SQL_BEGIN` transaction.
- `eod_jobs_core`: orchestrator, not a transaction owner (ADR-0006). START/FINISH
  run autocommit; money work happens in the called modules' own transactions.
  No orphan `COMMIT`/`ROLLBACK` without `BEGIN`.
- `auth_password_core`, `hashlen_core`: no admin guard / no bind slots (utility).
- `user_core`: 5 bind slots (sufficient for its queries).

## Standardization rules

- All SQL must use `SQL_PREPARE_EXEC*` with `?` placeholders.
- Every write path wraps in `SQL_BEGIN` / `SQL_COMMIT` / `SQL_ROLLBACK`.
- Admin-only actions call `ALLOW-ADMIN` or `ALLOW-SUPER-ADMIN`.
- Keep `WS-PREP-SQL` ≤ 1024 chars and params ≤ 6 (7 for EXEC7).
- Warning baseline must be 0 for every module.

## References

- `docs/LINKAGE.md`
- `docs/COVERAGE.md`
- `docs/MODULE_AUTHORING.md`
- `docs/adr/0014-linkage-only-classification.md`
