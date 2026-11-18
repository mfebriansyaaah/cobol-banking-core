# Dataset Card — Cobol Banking Core (audit snapshot)

- Code HEAD: `cfe4a8a5` (Phase 1 train curation; prior audit `51aba228`)
- Approval record: `80fb72b5` (typed owner approval + first verified source export)
- Release export snapshot: `phase1` export at `cfe4a8a5` (source 855 files,
  train 720 files; `sha256sum -c` all OK, gitleaks clean)
- Date: 2026-11-18
- Profile default: `source` (see `scripts/export_dataset.sh`)

> **Phase 1 update (2026-11-18):** the `train` profile is now data-driven from
> `manifest/module_quality.json`. It excludes all 40 non-recommended modules
> (including the 8 clone-shaped modules), their DB suites and dedicated table
> cases, and all generated route files except the `card.js` exemplar. The
> route spec (`middleware/spec/routes.yaml`) remains the source of truth. See
> `scripts/train_profile.mjs` and its `--check` gate.

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
database/schema_full.sql  database/schema_v2.sql.gz
docs/openapi.yaml  docs/DATA_DICTIONARY.md  docs/STATUS.md
docs/MODULE_INDEX.md  docs/COMPLEXITY_BASELINE.md
contracts/actions.yaml  manifest/actions.json
tests/contracts/route_field_order.json
```

Plus `.datasetignore` local paths (backups, artifacts, coverage,
node_modules, cobol/bin+build, tests/.dbenv, logs, dumps, env files).

| Profile | Source-tree files | Archive | Generated snapshots | Train curation | Use |
| --- | ---: | --- | --- | --- | --- |
| `source` | 855 | no | no | n/a | reproducible source |
| `train` | 720 | no | no | recommended only + `card.js` exemplar | training corpus |
| `verification` | 1,542 | yes | yes | n/a | full gates |
| `full` | 1,542 | yes | yes | n/a | archival |

`train` is the training corpus, **not** a runnable tree; use
`verification`/`full` to run gates. It contains 31 recommended modules
(23,273 COBOL lines), `main_logic`, the route spec, and one generated route
exemplar.

Per-module quality/tier/coverage metadata is in
`manifest/module_quality.json` and `docs/MODULE_QUALITY.md`.

`verification` profile keeps generated files (needed to run gates).
`full` profile exports all tracked files.

Every export writes `DATASET_INFO.json` (commit, timestamp, profile,
fileCount) and `SHA256SUMS`, then runs a gitleaks scan (must be clean).

## Test evidence (pre-Phase-1 snapshot; current Phase 1 checks below)

- Phase 1 (this HEAD): `npm run lint` 0, `format:check` clean, `test:scripts`
  497/497, gateway unit 149/149, `tests/run_all.sh fast` GREEN (235 table
  cases + 13 amount matrix), docs/module-reference gates clean, both train and
  source exports gitleaks-clean and `sha256sum -c` verified.
- Gateway unit (pre-Phase-1 snapshot): 147/147 pass.
- Script gate unit tests: 470/470 pass.
- Gateway JUnit count: 347 assertions (baseline re-pinned after quarantine removal).
- ESLint: 0 errors, 9 complexity warnings (ratchet `--max-warnings 9`).
- COBOL syntax: 0 warnings (was 43 copybook warnings, fixed C-03).
- DB suites: `auth_shell` 51/51 (x2), `card` 52/52 (x2),
  `card_posting` 103/103, `collection` 56/56, `lending_posting` 173/173,
  `payment_race` 55/55, `auth_session` 23/23, schema fleet 214 assertions.
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
- Full `tests/run_all.sh full` serial: GREEN (2x).
  Parallel-shard keyed-race flakes were root-caused and fixed: a late
  loser can legitimately replay `SUCCESS` after the winner commits, so
  "exactly one SUCCESS + one `*_IN_PROGRESS`" was scheduler-dependent.
  `assert_race_outcomes` now asserts at least one winner plus only
  idempotent outcomes, while every suite still asserts the money
  invariants (single posting/journal, exact amounts). Non-keyed guard
  races (`OVERPAID`, `INVALID_AMOUNT`, `INSUFFICIENT_FUNDS`,
  `LIMIT_EXCEEDED`) still require exactly one winner because no replay
  path exists.
  Also root-caused: an incremental-build staleness incident (idempotency
  replay returned `TRANSFER_IN_PROGRESS`) disappeared after
  `rm -rf cobol/build cobol/bin && ./build.sh`; R-02 mandates clean builds.
  The mutation harness had the same class of bug (restored sources keep old
  mtimes, so the final incremental build could retain M17); the harness now
  does a clean rebuild and was re-run 16/16 KILLED with a clean tree.
- Gitleaks worktree + export: 0 findings; history mirror sanitized.
- Premerge `--ci-parity`: **GREEN** at `51aba228` (full suite, probes 17/17,
  strict counts 2553 assertions, coverage, benchmarks, migration rollback +
  backup/restore drills, full lint/security, offline harnesses). This is
  the authoritative R-02 gate.

## Known gaps (honest)

1. All 40 non-recommended modules (including 8 clone-shaped and 5 exact
   clones) are kept in `source` for reproducibility but excluded from `train`.
   The `source` file count therefore includes them; `train` keeps only the 31
   recommended modules.
2. Integration backlog: 202 items, 147 OPEN (registry/parser fixed A-04;
   items are linkage evidence gaps, not code defects).
3. `ref_engine` COBOL coverage 0% (curated-core floor; tracked in
   `tests/coverage_floor_backlog.txt`, 9 entries).
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
