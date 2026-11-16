# Dataset Card — Cobol Banking Core (audit snapshot)

- Campaign HEAD: `5125e881` (`maint/audit-plan`; baseline `322255b7` on `main`)
- Date: 2026-11-16
- Profile default: `source` (see `scripts/export_dataset.sh`)

## License status

**APPROVED — typed owner approval recorded 2026-11-16.**
`docs/DATASET_LICENSE_APPROVAL.md` records Muhammad Febriansyah
(@mfebriansyaaah), Repository Owner / Copyright Holder, approving internal
training/evaluation plus limited commercial use by the holder and written
authorized entities; no public redistribution/resale/sublicensing. No fixed
expiry; revocable in writing or on LICENSE/ownership change. This is a
bounded dataset approval, not a change to the proprietary `LICENSE`.

## PII status

- Source fixtures are synthetic (`admin@test.com`, NIK `3171010101900001`,
  `+6281234567890`, `wilayah.json` public region data).
- Git history author emails include personal addresses; sanitized export
  lives only in the mirror clone `/tmp/opencode/cobol-export.git`
  (see G-02; `git log` there shows only `@users.noreply.github.com`).
- Local-only artifacts (`backups/` 72M physical backup, `artifacts/`,
  `node_modules/`, `tests/.dbenv`, `cobol/bin+build/`) are gitignored and
  excluded from export via `git archive` + profile exclusion lists.
- Secret history review: `docs/SECURITY_HISTORY_REVIEW.md` — 7 gitleaks
  history findings, all synthetic test fixtures / docs false positives,
  0 live credentials. Worktree scan clean.

## Included / excluded paths

`source` profile excludes generated/noise artifacts:

```text
database/migrations/archive/
database/schema_full.sql  database/schema_v2.sql
docs/openapi.yaml  docs/data_dictionary.md  docs/STATUS.md
docs/MODULE_INDEX.md  docs/COMPLEXITY_BASELINE.md
contracts/actions.yaml  manifest/actions.json
tests/contracts/route_field_order.json
```

Plus `.datasetignore` local paths (backups, artifacts, coverage,
node_modules, cobol/bin+build, tests/.dbenv, logs, dumps, env files).

`verification` profile keeps generated files (needed to run gates).
`full` profile exports all tracked files.

Every export writes `DATASET_INFO.json` (commit, timestamp, profile,
fileCount) and `SHA256SUMS`, then runs a gitleaks scan (must be clean).

## Test evidence (this snapshot)

- Gateway unit: 147/147 pass.
- Script gate unit tests: 469/469 pass.
- Gateway JUnit count: 347 assertions (baseline re-pinned after quarantine removal).
- ESLint: 0 errors, 9 complexity warnings (ratchet `--max-warnings 9`).
- COBOL syntax: 0 warnings (was 43 copybook warnings, fixed C-03).
- DB suites: `auth_shell` 51/51 (x2), `card` 52/52 (x2),
  `card_posting` 103/103, `auth_session` 23/23, schema fleet 214 assertions.
- Static gates: manifest, docs, dependency graph, purity, transaction
  ownership, call graph, bind slots, field sizes, action coverage, case
  actions, suite coverage, program signatures, error codes, openapi,
  request-state reset (43 modules), module size — all OK.
- Copybook baseline: vars 243 → 240 (reviewed drift, S-03).
- Mutation: 16/16 killed (M1–M17 incl. new bind-swap M17).
- Probes: 17/17 detected (p5b static via `bind_slots`; M17 runtime backstop).
- Coverage: gateway 98.94%/84.33% (≥ baseline); COBOL curated total
  49.24% (≥ 30% floor), copybooks union 83.04% (≥ 80.84%). Per-module
  baseline re-pinned for the C-06 entry-reset line attribution shift
  (reviewed `--cobol-only` run; no test deletion).
- Schema drift: `check_schema_drift.sh` green.
- Full `tests/run_all.sh full` serial: GREEN (see R-02 evidence).
  Two parallel-shard race flakes observed during the campaign
  (`payment_race` 52/54, `card_posting` 101/103 — "exactly one winner"
  assertions); both suites green in isolation and on serial re-run.
  Also root-caused: an incremental-build staleness incident (idempotency
  replay returned `TRANSFER_IN_PROGRESS`) disappeared after
  `rm -rf cobol/build cobol/bin && ./build.sh`; R-02 mandates clean builds.
  The mutation harness had the same class of bug (restored sources keep old
  mtimes, so the final incremental build could retain M17); the harness now
  does a clean rebuild and was re-run 16/16 KILLED with a clean tree.
- Gitleaks worktree + export: 0 findings; history mirror sanitized.
- Premerge `--ci-parity`: failed at the 4-shard DB phase on the known
  `payment_race_db_tests.sh` parallel flake (52/54; serial 54/54 twice).
  All gates before that (build, full suite, probes, counts) were green;
  this is a test-harness race, not a code regression. R-02 keeps this
  residual open for a dedicated test-stability follow-up.

## Known gaps (honest)

1. 5 template-clone modules frozen per ADR-0012 (excluded from `source`).
2. Integration backlog: 202 items, 147 OPEN (registry/parser fixed A-04;
   items are linkage evidence gaps, not code defects).
3. `ref_engine` COBOL coverage 0% (curated-core floor; tracked in
   `tests/coverage_floor_backlog.txt`, 8 entries).
4. `/auth/refresh` intermittent-500 history: resolved — 300 serial runs
   green, zero `gateway_error` lines (C-04); quarantine removed.
   The historic CI flake reproduces only under parallel shard load,
   not as a code defect.
5. MinIO upstream image `minio/minio:latest` no longer exists on
   Docker Hub; local vault tests use MinIO service — use
   `quay.io/minio/minio:latest` if re-provisioning (environment note,
   not a repo change).
6. Private-repo branch protection unavailable (compensating controls in
   `docs/GOVERNANCE.md`).

## Reproduce

```bash
git checkout maint/audit-plan
npm ci && npm --prefix middleware ci
./build.sh
DB_HOST=127.0.0.1 DB_PORT=3307 DB_NAME=cobol_db \
  DB_USER=cobol_app DB_PASS=cobol_pass \
  DB_MIGRATE_USER=cobol_migrate DB_MIGRATE_PASS=cobol_migrate_pass \
  tests/run_all.sh full
bash scripts/export_dataset.sh --profile source --out /tmp/opencode/dataset-source
cd /tmp/opencode/dataset-source && sha256sum -c SHA256SUMS
```
