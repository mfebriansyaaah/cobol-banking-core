# Contributing

This repository is proprietary; see [LICENSE](LICENSE). Contributions are
accepted only from people authorized by the owner.

## Ground rules

- One concern per pull request. Do not mix a domain wave, a refactor, and
  documentation in one PR.
- Branch from `main`; never push directly to `main`. See
  [Branching and merge model](docs/BRANCHING.md) for the train, merge method,
  and final `git ls-remote --heads origin` check (only `main` remains).
- Prefer PRs under 500 changed lines and under 5 working days (ceiling 1500
  with a recorded exception — see `docs/BRANCHING.md`). Split large waves.
- No merge with a failing CI check. Required checks are listed in
  [CI status](docs/CI.md).
- Do not add secrets, real customer data, or personal email addresses to code,
  tests, fixtures, migrations, or commit metadata.
- Money-path changes (wallet, auth, payments, treasury, GL, settlement) require
  two approvals under the policy in [docs/GOVERNANCE.md](docs/GOVERNANCE.md).
- Ownership and review SLA live in [docs/OWNERSHIP.md](docs/OWNERSHIP.md).
  Bus factor 1 is a known gap; second owners are required for 9/10.

## Local gate

Run the local pre-merge gate before opening or updating a PR:

```sh
bash scripts/ci/premerge.sh
```

For critical money-path changes, run the exact CI parity gate on a dedicated
database (never `cobol_db`; see [docs/CI.md](docs/CI.md)):

```sh
DB_NAME=cobol_db_premerge scripts/dev/setup-test-db.sh
DB_NAME=cobol_db_premerge bash scripts/ci/premerge.sh --ci-parity
```

`--ci-parity` is the exact-parity money-path gate on a dedicated database
(never `cobol_db`): full suite, probes, count/docs/contract/schema/warnings/
coverage gates, benchmarks, both drills, full lint + security (including
actionlint, YAML lint, SAST, and gate unit tests), offline harnesses, and the
coverage mapper. Curated COBOL coverage is opt-in via `--cobol-coverage`
(needs GnuCOBOL 3.2 with `cobc --coverage`). Run
`bash scripts/ci/premerge.sh --print-plan` for the exact step list and the
deliberate exclusions (in-job sharding instead of the CI matrix, no CodeQL
upload, no branch-protection remote state).

Documentation-only PRs take a fast path: when every changed file is docs
(`docs/**`, root doc files, issue/PR templates, `CODEOWNERS`), CI skips the
heavy jobs (`db-shards`, `coverage-pr`, `db-aggregate`) and runs only
lint, build, and the `test` gate. Add the `ci:full` label to force a full
run (e.g. when a docs change touches generated content). See
[docs/CI.md](docs/CI.md) for the exact rules.

It runs the static gates and the fast suite by default (probes, docs, and
the full DB/gateway suite are opt-in via `--probes`, `--docs`, `--full`;
run with `--help` for details). CI runs the full DB, integration, fuzz,
migration-apply, schema-rebuild, performance, and coverage jobs. For the local
test database setup, the isolation model, and troubleshooting, see
[docs/TESTING.md](docs/TESTING.md).

## Adding or changing a domain

1. Add or update `cobol/src/<domain>_core.cob` using the established 9-action
   contract (`CREATE`, `LIST`, `GET`, `CALC`/domain action, `UPDATE`/`CLOSE`,
   `SUMMARY`, `AUDIT`, `VALIDATE`).
2. Use `SQL_BEGIN` / `SQL_COMMIT` / `SQL_ROLLBACK`, `SQL_PREPARE_EXEC*` with
   placeholders, and `ALLOW-ADMIN` / `ALLOW-SUPER-ADMIN` where required.
3. Add the migration under `database/migrations/`; never hand-edit
   `database/schema.sql` for an incremental change.
4. Add the route with fields in the exact COBOL parameter order, static paths
   before `/:id`, and a `PATTERNS` entry for every named field.
5. Add table cases under `tests/cobol/cases/` and a DB suite under `tests/db/`.
6. Register the suite and expected counts in `tests/baseline_counts.txt` and
   `tests/warning_baseline.txt`. Counts are load-bearing: regenerate with
   `node scripts/check_test_counts.mjs --report-dir artifacts --write`
   (never hand-edit), review the diff, and document reason/before/after in
   the PR — see the baseline section in [docs/TESTING.md](docs/TESTING.md).
7. Add the module to `build.sh`.
8. Regenerate and check the manifest:

   ```sh
   node scripts/generate_manifest.mjs .
   node scripts/check_manifest.mjs .
   ```

9. Update documentation and regenerate generated docs:

   ```sh
   node scripts/docs_stats.mjs --write
   node scripts/check_docs.mjs
   ```

## Documentation changes

- Generated files: `docs/STATUS.md`, `docs/MODULE_INDEX.md`, and the generated
  block in `README.md`. Edit the generator, then run
  `node scripts/docs_stats.mjs --write`.
- Hand-maintained: `docs/COVERAGE.md`, `docs/GOVERNANCE.md`, `docs/BRANCHING.md`,
  `docs/CI.md`, `docs/OWNERSHIP.md`, ADRs, runbooks,
  `docs/domain_overview.md`, and `docs/data_dictionary.md`.
- Every local Markdown link must resolve. `node scripts/check_docs.mjs` checks
  links and generated stats.

## Commit and PR style

- Use a clear imperative subject, for example `fix(routes): resolve /sessions
  shadowing`.
- Explain the behavior change, the risk, and the rollback in the PR template.
- Include the commands you ran and their result.
- If a governance rule cannot be met, record the exception in the PR using the
  template in [docs/GOVERNANCE.md](docs/GOVERNANCE.md).

## Security

Do not open a public issue for a vulnerability. Follow [SECURITY.md](SECURITY.md).
