# CI Status

> R0 readiness branch 00A. Single source of truth for CI triggers, required
> checks, cost, enforcement, and rollout. Last verified: 2026-11-19.
> Phase 0 branch 01 restores automatic triggers; see “Current status” below.
> Current branch-protection state: ACTIVE (verified 2026-11-19 via API).
> See “Branch protection” below.

<!-- BEGIN GENERATED TOC -->

- [Current status: AUTOMATIC (restored in Phase 0 branch 01)](#current-status-automatic-restored-in-phase-0-branch-01)
- [Trigger matrix (target, after unpark)](#trigger-matrix-target-after-unpark)
- [Docs-only fast path (CI-011)](#docs-only-fast-path-ci-011)
- [CI contract (`scripts/check_ci_contract.mjs`)](#ci-contract-scriptscheck_ci_contractmjs)
- [Required checks](#required-checks)
- [Job durations and timeouts](#job-durations-and-timeouts)
- [DB snapshot producer + consumers (CI-008A/CI-008B)](#db-snapshot-producer--consumers-ci-008aci-008b)
- [Rerun-safe artifacts and failure attribution (CI-013)](#rerun-safe-artifacts-and-failure-attribution-ci-013)
- [Failure notifications (`notify`)](#failure-notifications-notify)
- [How to run locally](#how-to-run-locally)
- [Cost model (measured 2026-11-05; replaces the planning ceiling below)](#cost-model-measured-2026-11-05-replaces-the-planning-ceiling-below)
- [Cost plan (planning ceiling, superseded 2026-11-05 — historical)](#cost-plan-planning-ceiling-superseded-2026-11-05--historical)
- [Enforcement](#enforcement)
- [Rollout and communication (T-047)](#rollout-and-communication-t-047)
- [R0 readiness (2026-11-04, updated in 00B)](#r0-readiness-2026-11-04-updated-in-00b)
  - [R0 sign-off (T-052, 2026-11-04) — PASSED](#r0-sign-off-t-052-2026-11-04--passed)
  - [Owner sign-off (R0 criterion 1) — signed 2026-11-04](#owner-sign-off-r0-criterion-1--signed-2026-11-04)
  - [Evidence (run 41772256921, 2026-11-04)](#evidence-run-41772256921-2026-11-04)
- [Branch-train dry-run (T-058, done in 00B)](#branch-train-dry-run-t-058-done-in-00b)
- [R0 final record (T-052, 2026-11-04) — PASSED](#r0-final-record-t-052-2026-11-04--passed)
- [Known-red / preflight](#known-red--preflight)
- [G1 docs-only fast-path proof (2026-11-06)](#g1-docs-only-fast-path-proof-2026-11-06)
- [G1 ci:full override proof (2026-11-06)](#g1-cifull-override-proof-2026-11-06)
- [G1 option-A fast-path proof (2026-11-07)](#g1-option-a-fast-path-proof-2026-11-07)
- [Branch protection — restore runbook (ACTIVE since 2026-11-19)](#branch-protection--restore-runbook-active-since-2026-11-19)

<!-- END GENERATED TOC -->

## Current status: AUTOMATIC (restored in Phase 0 branch 01)

`ci.yml` runs on `push: [main]`, `pull_request`, and `workflow_dispatch`.
`nightly.yml` (`0 2 * * *`), `coverage.yml` (`30 2 * * *`), and `codeql.yml`
(`0 3 * * 1`) run on schedule plus `workflow_dispatch`. `codeql.yml` also
runs on `push: [main]` and `pull_request` (CI-003).

T-003 minimal bridge: skipped with reason — billing is fixed (public repo, run
41772256921 executes), full CI is restored, so a bridge would only duplicate
the gate and waste minutes.

## Trigger matrix (target, after unpark)

| Event | Workflow | Jobs |
| --- | --- | --- |
| `pull_request` | `ci.yml` | changes, lint, coverage (always for non-docs PRs); build, docker-build, db-snapshot, schema-drift, test, db-shards (2), db-aggregate, coverage-pr (all gated on the change set; docs-only PRs run only changes + lint; `docker-build` runs only when the image can change; `coverage-pr` only when curated COBOL input changed) |
| `push: [main]` | `ci.yml` (+ `db-ops` on push/dispatch) | changes, lint, build, docker-build, db-snapshot, db-ops. Docs-only pushes are filtered at the workflow trigger. `schema-drift` is PR + nightly only (the PR gate already proved it; no post-merge re-run). The PR-only DB gate (`test`, `db-shards`, `db-aggregate`) and `coverage` do not run on push; branch protection guarantees they ran on the PR. `coverage` runs on manual dispatch. |
| nightly `0 2 * * *` | `nightly.yml` | full-twice (`full twice + drills`) + benchmark + load test + flake compare |
| nightly `30 2 * * *` | `coverage.yml` | coverage (full COBOL + gateway measurement) |
| weekly `0 3 * * 1` | `mutation.yml` | mutants (`money-path mutants`) |
| `pull_request`, `push: [main]`, schedule, manual | `codeql.yml` | analyze (`Analyze (javascript/cpp)`) JS + C analysis, SARIF uploaded to code scanning |
| weekly Monday `0 12 * * *` | `ci-report.yml` | report (`ci-report`) weekly metrics + SLO evaluation + `ci-metrics` artifact |

Restore order: revert `7e030110` (PR/push), then `1dfc11de` (schedules).
Verify with a throwaway PR: lint fails on broken shell, build fails on broken
COBOL, db-aggregate fails on deleted assertion, db-ops runs on `main`
(push) while PRs skip the drills, nightly starts on schedule.

## Docs-only fast path (CI-011)

PRs that touch only documentation (`docs/**`, root doc files, issue/PR
templates, `CODEOWNERS` — classified by `scripts/ci/classify_changes.mjs`,
unit-tested) skip every heavy job. Only `changes` and `lint` run (a skipped
required check counts as success; `ci:full` forces a full run on demand).
`build` is gated too: a docs-only change cannot alter compiled behavior, and
the old unconditional build was the most expensive part of a docs PR. On
`push`, docs-only commits are filtered by `paths-ignore`; `db-ops` is likewise
skipped for docs-only changes (nightly covers the drills).

CI-009 update: `coverage` is now a real required PR gate, not a skipped
manual-only context. It runs the gateway suite once with coverage and JUnit
output; `test` sets `SKIP_GATEWAY=1` so the same suite is not executed twice.
`coverage-pr` remains the independent curated-COBOL coverage gate. Skipped
required checks still count as success for docs-only PRs.

CI-003 evidence (2026-11-05, Option A): code scanning works end-to-end with
no UI step — the PR-triggered CodeQL run
(`actions/runs/41976873579`, branch `ci/ci-p0-03-codeql-green`) uploaded SARIF
for both `javascript` and `cpp`, and
`code-scanning/analyses` lists both tools with 0 open alerts. The earlier
"not enabled" failure (2026-11-02) no longer reproduces; `gh` + runs suffice.

CodeQL scope: the JavaScript gateway and the C crypto helpers
(`cobol/c_lib`, self-contained, traced with gcc). COBOL is out of scope —
no CodeQL extractor exists. CodeQL stays informational (not a required
check) until one green run plus an alert-triage pass.

CI-006 evidence (2026-11-05): `scripts/check_docs.mjs` now fails on stale
fleet counts, wrong required-check names, and retired claims (unit-tested in
`scripts/test/stale_claims.test.mjs`); `scripts/ci/ci_metrics.mjs` records
before/after evidence under `artifacts/ci-audit/<date>/`. All counts above
were re-verified against the tree on 2026-11-05. Next docs review: with the
G1 sign-off, or sooner if the DB fleet grows past 80 suites (revisit the
shard-count prose and the cost model).

The collector also separates **primary** from **cascaded** failures
(2026-11-11): a failed job is cascaded when a transitive `needs` dependency
also failed in the same run (e.g. `db aggregate` after `test`). `--json` adds
`primary_failure_rate_pct`, `cascaded_failures`, and `primary_failed_jobs`;
without a dependency graph every failure counts as primary (fail-safe).
Parse errors degrade to the unclassified view, never hide a failure.

## CI contract (`scripts/check_ci_contract.mjs`)

The lint job runs `node scripts/check_ci_contract.mjs .` on every PR and push.
It fails the run when any of these invariants break. Unit tests live in
`scripts/test/check_ci_contract.test.mjs`; negative fixtures live in
`tests/fixtures/ci-contract/`.

Enforced invariants (CI-001):

- Triggers: `ci.yml` has `pull_request` (not restricted to `closed`) and
  `push` to `main` (`branches-ignore: [main]` is rejected); `nightly.yml`
  (`0 2 * * *`), `coverage.yml` (`30 2 * * *`), and `codeql.yml` (weekly)
  have schedules.
- Required jobs: `ci.yml` contains `lint`, `build`, `test`, `db-shards`,
  `db-aggregate`, `coverage`.
- Display names: GitHub matches check runs by `name:`, not job ID.
  Expected names are `lint`, `build`, `test`, `db shard <n>` (prefix),
  `db aggregate` (space), `coverage`, `coverage-pr`. A rename to
  `db-aggregate` (hyphen) fails the contract instead of blocking every PR.
- Timeouts: every job in every workflow declares `timeout-minutes`.
- Action pins: every remote `uses:` is a 40-hex SHA (floating tags like
  `@v4` fail); local `./...` actions are exempt.
- Permissions: every workflow declares `permissions` (or every job does);
  `write-all` is rejected.
- Shard consistency: the `db-shards` matrix size, the `DB_SHARD_COUNT` the
  shard runner uses, and the `aggregate_shard_reports.sh` argument must agree.

## Required checks

Phase 0 (before G0):

- `lint`
- `build`
- `test`
- `db aggregate` (job ID `db-aggregate`; GitHub matches the check-run **name**
  with a space — `db-aggregate` with a hyphen never reports, use the space form)
- `coverage`
- `coverage-pr` (curated COBOL coverage gate; required since CI-002)

`db-ops` (rollback/backup drills on push `main` + `workflow_dispatch`) is
intentionally not a required PR check: it never runs on `pull_request`, so
requiring it would block every PR forever. Main-line evidence comes from the
push run plus nightly, which runs the same three checks.

Phase 1 adds (after WP-1.4 first green run):

- `security` (semgrep + gitleaks + npm audit + custom SAST + CodeQL CLI/SARIF)

Rules:

- A red required check blocks merge. No admin bypass.
- 1 approval; 2 approvals for critical money path: wallet, auth, payments,
  treasury, GL, settlement.
- CODEOWNERS review required; dismiss stale approvals; block force pushes and
  branch deletion.
- Until a ruleset or merge bot is active, 9/10 is capped at 8.5. See
  “Enforcement” below.

## Job durations and timeouts

| Workflow / job | Timeout | Notes |
| --- | --- | --- |
| `ci.yml` changes | 5 min | docs/docker/coverage classifier (`scripts/ci/classify_changes.sh`); every heavy job gates on it |
| `ci.yml` lint | 15 min | shellcheck, eslint, prettier, markdownlint, actionlint, yamllint, promtool, semgrep, gitleaks, the full 38-gate static fleet, docs stats, gate probes, PR-size report, gate unit tests, npm audit, CI docs check |
| `ci.yml` build | 10 min | pure producer: cached COBOL build + warning ratchet + `cobol-binary` artifact; no lint/static gates |
| `ci.yml` docker-build | 15 min | production image build + native linkage check (no push); parallel with `build` |
| `ci.yml` db-snapshot | 10 min | schema + migrate + ledger check + gzip DB snapshot + normalized `schema-fresh` artifact (pure producer; does not wait for `build`) |
| `ci.yml` schema-drift | 10 min | compares the producer's normalized `schema-fresh` artifact with committed `schema_full.sql`; no second DB provisioning, and a drift failure blocks merge without blocking DB consumers |
| `ci.yml` test | 25 min | PR-only non-DB gate: integration, gateway, error harness, table/amount tests; `SKIP_STATIC_GATES=1` because `lint` owns the gate fleet |
| `ci.yml` db-shards (×2) | 25 min each | PR-only, one LPT shard per runner; runtime deps only (no npm install) |
| `ci.yml` db-aggregate | 10 min | PR-only merge of test, shard, and coverage reports + inventory + count gate + summary |
| `ci.yml` coverage | 20 min | PR gateway coverage gate + manual dispatch: runs the gateway suite once with coverage/JUnit; `test` skips its gateway phase |
| `ci.yml` coverage-pr | 35 min | curated COBOL, impact-selected: skipped unless the change set touches curated inputs (`coverage_relevant`; trigger groups in `docs/COVERAGE.md`); compiles its own instrumented binary, no `build` dependency |
| `ci.yml` db-ops | 20 min | rollback, backup/restore (push `main` + dispatch only; not a PR required check) |
| `codeql.yml` analyze | 20 min | JS + C, SARIF uploaded to code scanning; path-filtered on PR/push, weekly schedule unfiltered |
| `coverage.yml` coverage | 45 min | full COBOL + gateway; shares the COBOL object cache |
| `coverage.yml` notify | 5 min | open/close `ci-failure` issue |
| `nightly.yml` full-twice | 180 min | full twice + drills + benchmark + load + flake compare; full coverage belongs to `coverage.yml` |
| `nightly.yml` notify | 5 min | open/close `ci-failure` issue |
| `mutation.yml` mutants | 120 min | money-path mutants + anchor guard (weekly); warm COBOL objects |
| `mutation.yml` notify | 5 min | open/close `ci-failure` issue |
| `ci-report.yml` report | 30 min | weekly metrics + SLO checks (`ci-metrics` artifact, 30 days) |
| `ci.yml` notify | 5 min | push `main` only; open/close `ci-failure` issue (never a required check) |

## DB snapshot producer + consumers (CI-008A/CI-008B)

Shared bootstrap lives in composite actions (`.github/actions/setup-cobol`,
`.github/actions/db-bootstrap`, `.github/actions/upload-diagnostics`) so the
six DB consumers (`test`, `db-shards`, `coverage`, `coverage-pr`, `db-ops`,
`nightly.yml` `full-twice`) share one restore → grants → seed order instead
of duplicated inline shell. `setup-cobol` pins the GnuCOBOL 3.2 toolchain for
the `build` job and every job that runs the `cobol-binary` artifact (`test`,
`db-shards`, `coverage`, `coverage-pr`): the artifact links 3.2's
`libcob.so.4`, which the apt gnucobol 3.1.2 runtime cannot provide.
`upload-diagnostics` standardizes failure forensics.

The `db-snapshot` job publishes one migrated gzip snapshot per run
(`db-snapshot` artifact, retention 1 day) so DB jobs can restore instead of
replaying schema + all migrations. Every DB job (`test`, `db-shards`,
`coverage`, `coverage-pr`, `db-ops`) downloads it and restores it with
`scripts/ci/restore_db_snapshot.sh`, falling back to schema + migrations
when the artifact is missing (expired retention, failed producer job).
The same job also publishes `schema-fresh` (normalized `mysqldump --no-data`
from the already-migrated database, retention 1 day). `schema-drift` consumes
that artifact and only compares it with the committed baselines, so it never
provisions a second database. It is not a dependency of the DB consumers: a
drift failure blocks merge through `db aggregate` while `test`/`db-shards`
continue with the data snapshot.

Restore order per job (enforced by `restore_db_snapshot.sh` + job steps):

1. Download `db-snapshot` (`continue-on-error: true` — a missing artifact
   must fall back, never fail the job).
2. Restore the snapshot, or rebuild from `schema.sql` + `migrate.sh`.
3. `migrate.sh --check` must be green (runs inside the helper).
4. `database/grants.sh` **after** restore (restore recreates the database).
5. Job-specific seed (`run_all.sh` seeds itself; `coverage`/`coverage-pr`
   run `seed_test_data.sql`; `db-ops` drills seed themselves).

- Producer: `scripts/ci/build_db_snapshot.sh /tmp/cobol-snapshot.sql.gz`.
  Requires `DB_NAME`, `DB_MIGRATE_USER`, `DB_MIGRATE_PASS` (`DB_HOST`/`DB_PORT`
  default to localhost/3306); refuses system databases and empty names
  (exit 2); runs `migrate.sh --check` and aborts on pending migrations;
  dumps with `mysqldump --single-transaction --routines --triggers` (D5
  default — `--no-tablespaces` omitted: S1 confirmed the flag only in the
  MariaDB 11.8 client help, with no live dump/restore smoke, so the
  unverified flag stays out, matching every other in-tree dump call site);
  prints snapshot size and table count; never prints the password.
- Schema producer: `scripts/generate_schema_snapshot.sh --from-db "$DB_NAME"
  --out /tmp/schema-fresh.sql`. It dumps `--no-data` from the same migrated
  database and normalizes volatile bits exactly like the committed baseline;
  no throwaway database is created.
- Wired by `scripts/test/ci-wiring.test.mjs` (`build_db_snapshot` needle);
  offline guard tests in `tests/scripts/test_db_snapshot_guard.sh`.
- Live-DB acceptance (artifact size, restore round trip, job wall time)
  needs CI and is deferred: expected snapshot < 50 MB compressed and
  `db-snapshot` wall <= 3 min; the first green CI run records the actuals.
- Rollback: delete the `db-snapshot` job, the producer scripts, the
  `schema-fresh` artifact, and this section. Consumers are unchanged, so
  schema + migrate keeps working.

## Rerun-safe artifacts and failure attribution (CI-013)

Every `actions/upload-artifact` step sets `overwrite: true` (the pinned v4
action deletes a same-name artifact before uploading), so rerunning a failed
job never fails with "artifact already exists". Pinned by
`scripts/test/ci-wiring.test.mjs` (every upload-artifact step must set it).

When the `test` job does not succeed, `db-aggregate` still merges and
verifies shard reports, but skips only the assertion-count gate with an
explicit notice naming the `test` result — a red `test` job is never masked
by a follow-on "missing suite rows / no JUnit XML" failure.

## Failure notifications (`notify`)

Scheduled workflows (`nightly.yml`, `coverage.yml`, `mutation.yml`) and
`ci.yml` pushes to `main` run a `notify` job that opens or updates a
`ci-failure` issue (`scripts/ci/notify_failure.sh`). A failure creates or
comments the issue with the run URL, SHA, and failed jobs; the next green run
closes it. Triage steps live in `docs/runbooks/ci-failure.md`. `notify` is
never a required check.

SLO targets live in `docs/CI_SLO.md`, evaluated every Monday by
`ci-report.yml` (`scripts/ci/ci_weekly_report.mjs`); breaches open the
`ci-health` issue (`scripts/ci/ci_health_issue.sh`).

## How to run locally

```sh
# fast loop
make bootstrap
make test-fast

# targeted DB suite
tests/run_all.sh db --only loan
tests/run_all.sh db --only loan --repeat 5
tests/run_all.sh db --failed

# exact CI parity (dedicated DB, never cobol_db)
DB_NAME=cobol_db_premerge scripts/dev/setup-test-db.sh
DB_NAME=cobol_db_premerge bash scripts/ci/premerge.sh --ci-parity
```

`--ci-parity` runs `run_all.sh full` (fast, DB, integration, error harness,
gateway), probes, gate detection, count gate, docs, CI contract, schema
drift, build log + warning ratchet, gateway coverage, curated COBOL coverage
(only with `--cobol-coverage`, needs GnuCOBOL 3.2), benchmarks, both drills,
shell/JS/markdown/workflow/YAML lint, strict C, semgrep, secret scan, SAST +
SAST extra, gate unit tests, dependency audit, alert rules, offline harness,
and the coverage mapper. It must fail — not skip — when a tool is missing.

Exact scope is printed by `bash scripts/ci/premerge.sh --print-plan`:
in-job DB sharding instead of the CI `db-shards` matrix (same planner, one
runner), no CodeQL upload (GitHub security events exist only in CI;
semgrep/SAST run instead), no branch-protection remote state.

T-051 dry-run record (2026-11-04): first fully green `--ci-parity` on a
private MariaDB 11.8 instance (port 3307, provisioned via
`setup-test-db.sh`). Full serial+sharded fleet, probes, drills, and all
lint/security gates green, zero FAIL lines. Two discoveries fixed along the
way: per-run report dirs must not truncate mid-run, and worker DB dumps must
carry migration-seeded reference data (see branch 05 commits).

## Cost model (measured 2026-11-05; replaces the planning ceiling below)

| Workload | Measured basis | Job-minutes/month |
| --- | --- | ---: |
| PR gate | 29 job-min × 235 PRs/30d | 6,815 |
| Main push | 34 job-min × 150 pushes/30d | 5,100 |
| Nightly full + coverage + load | not yet measured (no nightly runs recorded as of 2026-11-05) | 9,000 (planning) |
| Mutation/CodeQL weekly | 120 job-min × 4 weeks | 480 |
| Subtotal | — | 21,395 |
| Buffer 30% | — | +6,419 |
| **Estimated total** | — | **~27,800 minutes/month** |

Measured per-run costs come from successful runs (`gh api .../actions/runs`
job timings): PR wall ~8 min / ~29 job-min, push wall ~15 min / ~34 job-min.
Run frequency (235 PR + 150 push per 30 days) reflects train velocity and
exceeds the old planning assumption (20 + 20). The repository is public, so
Actions usage is free within fair-use limits — this is a planning number,
not a billing blocker. If a private quota applies later, reduce in this
order: db-shards only on DB/COBOL PRs; coverage/CodeQL/mutation nightly;
nightly 3×/week. Never remove lint/build/test/count/security from `main`.
Re-measure after CI-007…CI-014 land and after two weeks of nightly runs,
then re-approve with the owner before re-privatizing.

## Cost plan (planning ceiling, superseded 2026-11-05 — historical)

| Workload | Assumption | Job-minutes/month |
| --- | --- | ---: |
| PR gate | 190 job-min × 20 PRs | 3,800 |
| Main push | 210 job-min × 20 pushes | 4,200 |
| Nightly full + coverage + load | 300 job-min × 30 nights | 9,000 |
| Mutation/CodeQL weekly | 120 job-min × 4 weeks | 480 |
| Buffer 30% | — | +5,244 |
| **Estimated total** | — | **~22,700 minutes/month** |

Private GitHub Free has a limited monthly minute quota; a 2-shard DB matrix
plus nightly can exceed it. While the repository is temporarily public,
Actions usage is free within fair-use limits, so this ceiling is a planning
number, not a billing blocker. If the budget is insufficient, reduce in this
order: db-shards only on DB/COBOL PRs; coverage/CodeQL/mutation nightly;
nightly 3×/week. Never remove lint/build/test/count/security from `main`.
Record actual minutes after two weeks and replace this table.

Approved 2026-11-04 by `@mfebriansyaaah`: ceiling ~22,700 minutes/month
accepted as planning number; re-approve with measured minutes before
re-privatizing the repository. Re-approval against the measured 2026-11-05
model above is pending.

## Enforcement

ACTIVE (verified 2026-11-19 via API): branch protection on `main` requires `lint`,
`build`, `test`, `db aggregate`, `coverage`, `coverage-pr` (not strict:
checks must pass, but the PR need not contain the latest `main`), merge
commits, `enforce_admins` on; force pushes and branch deletion blocked; no
review requirement (solo-owner flow), linear history not required.
Red-PR proof is recorded below.

Naming trap (burned us on PR #510): GitHub matches the check-run **name**
(`db aggregate`, with space — the job `name:`), not the job ID
(`db-aggregate`). Requiring the hyphen form blocks every PR forever.

CI-002 evidence (2026-11-05): `coverage-pr` added to required status checks
via API (`required_status_checks/contexts`: `lint`, `build`, `test`,
`coverage`, `db aggregate`, `coverage-pr`; strict at the time). Red-proof: PR #532
(`ci/ci-p0-02-red-proof`, COBOL floor forced to 100) failed `coverage-pr`
and showed `mergeStateStatus: BLOCKED`; closed unmerged, branch deleted.
Strictness removed 2026-11-05 (owner decision): checks stay required,
up-to-date branch no longer enforced.
`coverage-pr` is now a merge-blocking gate, not an advisory check.

Notes:

- Repository rulesets on this plan reject the `pull_request` and
  `required_status_checks` rule types (verified 2026-11-04), so the classic
  Branch Protection API is used instead. The draft
  `.github/rulesets/main.json` is superseded and removed in branch 02.
- Revisit rulesets if the plan upgrades.

Red-PR proof (T-004, this branch): a deliberately red PR is opened below and
shown unmergeable; it is closed unmerged afterwards. Evidence linked in the
branch 02 PR body.

Pre-push hook (`scripts/dev/install-hooks.sh`, wired via `bootstrap.sh`):
also installs a pre-commit hook that regenerates README/docs stats
(`SKIP_DOCS_STATS=1` bypasses with a warning), so the docs gate never
goes red just because a commit touched COBOL or routes.

- Critical money path: `premerge.sh --ci-parity`.
- Other financial domains: `premerge.sh --all`.
- Docs-only: `premerge.sh` (fast).
- `SKIP_PREMERGE=1` only with a recorded reason; logged to
  `artifacts/premerge-skips.log`.

Required evidence for G0 (done in branch 02): protection object via API plus a
deliberately red PR that cannot merge (closed unmerged).

## Rollout and communication (T-047)

- Announce enforcement 5 working days before enabling required checks.
- Publish this file as the single source of truth.
- Hold two office hours in the first week.
- Publish weekly: pass rate, action coverage, coverage, open flake age,
  security findings, Actions minutes vs budget.
- Emergency hotfix: owner approval, `--ci-parity` waived only with a recorded
  reason, a full post-merge run mandatory. Record the exception in the PR.

## R0 readiness (2026-11-04, updated in 00B)

| # | Criterion | Status |
| --- | :--- | --- |
| 1 | Owner decisions signed | Met — signed 2026-11-04, see below |
| 2 | Billing fixed | Met — run 41772256921 executes (build + 4 db-shards success, test in progress 2026-11-04); billing no longer aborts runs. Lint/coverage failures are pre-existing gates, not billing. |
| 3 | Enforcement access verified | Met — `gh api .../rulesets` returns `[]` rc=0 2026-11-04; draft in `.github/rulesets/main.json` valid (4 rules); active blocking is G0 |
| 4 | Tooling pinned | Met (binary SHAs) — `scripts/ci/tool-checksums.txt` verified 2026-11-04 for shellcheck, shfmt, actionlint, promtool, gitleaks; image digest + CodeQL/diff-cover deferred to Phase 1 |
| 5 | Branch-train dry-run | Met (local) — `chore/testing-r0-00-dry-run-1` (`e1c2cde8`) and `-2` (`2d9366fa`) merged to `main` and deleted; remote still only `main`; evidence in `docs/archive/dry-run-proof.md` |
| 6 | Cost approved | Met — ceiling ~22,700 min/month approved 2026-11-04 by `@mfebriansyaaah`; re-approve with measured minutes before re-privatizing |
| 7 | Named owners | Met — `@get-money-first` added as backup on every path 2026-11-04; see `docs/OWNERSHIP.md` |
| 8 | Executor independence | Met — tabletop 2026-11-04 by `@mfebriansyaaah` + `@get-money-first`, see `docs/archive/tabletop-r0.md` |
| 9 | Communication ready | Met — this file + rollout above |
| 10 | Day 0 preflight | Met (triaged) — full serial run 2026-11-04: 271/273 DB green; 2 env failures triaged in `docs/archive/known-red.md`; integration/gateway/smoke/harness/fuzz green; no orphans; artifacts in `artifacts/preflight-b6e4d7ce/` |
| 11 | Branching plan | Met — `docs/BRANCHING.md` added in 00A |

R0 passes when 1–8, 10, 11 are Met. Current composite: 9.0/10.

### R0 sign-off (T-052, 2026-11-04) — PASSED

R0 **passes**. Met: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11. Phase 0 may start.

### Owner sign-off (R0 criterion 1) — signed 2026-11-04

Approved by `@mfebriansyaaah` (repository owner):

- Billing / Actions: fix billing first; minimal bridge only for quota
  throttling, not suspension.
- Merge enforcement: GitHub Pro/public + ruleset; fallback merge bot; else cap
  9/10 at 8.5.
- Report layout: unique run directory + `artifacts/latest`, no append fallback.
- DB cleanup: single top-level EXIT trap in `tests/run_all.sh`.
- Action coverage denominator: all 527 route actions (2026-11-05, per
  `node scripts/check_action_test_coverage.mjs .`); HTTP-only
  is not shell-covered without owner + reason + expiry.
- UPDATE tests: 2-day spike; generator only if ≥80% uniform, else risk-based.
- Security: semgrep + gitleaks + npm audit + custom SAST on PR; CodeQL CLI +
  SARIF if GHAS unavailable.
- Test reporter: `dorny/test-reporter`, pinned SHA.
- Diff coverage: `diff-cover` + lcov; Cobertura for COBOL.
- Mutation: Stryker for JS money-path; hand-written COBOL mutants first.
- Post-deploy: out of scope for 9/10 (10/10 ops work).
- Money-path: wallet, auth, payments, treasury, GL, settlement (2 approvals);
  plus loan, deposit, card, collection for depth.
- Ownership: second owners required by 2026-12-04 or cap 9/10 at 8.5.
- Tool versions: pinned with checksums in `scripts/ci/tool-checksums.txt`.

### Evidence (run 41772256921, 2026-11-04)

`https://github.com/mfebriansyaaah/cobol-banking-core/actions/runs/41772256921`
executes (build success, db-shards 0–3 success, test in progress; lint fails at
Shell lint SC2164 in `scripts/test/run.sh`, coverage fails — both pre-existing,
triaged as G0/Phase 0, not billing).

## Branch-train dry-run (T-058, done in 00B)

1. `chore/testing-r0-00-dry-run-1` — commit `e1c2cde8`, merged to `main` via
   fast-forward, deleted locally.
2. `chore/testing-r0-00-dry-run-2` — commit `2d9366fa`, merged to `main` via
   fast-forward, deleted locally.
3. `git ls-remote --heads origin` shows only `refs/heads/main` (verified
   2026-11-04; local branches never pushed, so remote was never polluted).
4. Evidence: `docs/archive/dry-run-proof.md` plus `git log --oneline` showing both merges.

Status: done locally. Remote PR URLs: n/a (local-only dry-run; no remote branches created).

## R0 final record (T-052, 2026-11-04) — PASSED

R0 **passes** 2026-11-04. Met: 1–11 (criterion 10 triaged via `known-red.md`).
Composite: 9.0/10. Phase 0 may start with branch 01.

## Known-red / preflight

Day 0 preflight done 2026-11-04 (triaged, not green): see `docs/archive/known-red.md`
and `artifacts/preflight-b6e4d7ce/`. Before Phase 0, re-run the section 0.4
commands on a provisioned database (Docker 3307) and confirm zero red, or carry
the two env entries with owner and expiry.

## G1 docs-only fast-path proof (2026-11-06)

- Proof PR touches docs only to exercise selective CI (`docs_only=true`); `ci:full` label override verified separately.

## G1 ci:full override proof (2026-11-06)

- Proof PR touches docs only but carries the `ci:full` label to force `docs_only=false` (full run).

## G1 option-A fast-path proof (2026-11-07)

- Proof PR touches docs only; option A (D3 revised) skips `test` + `db-snapshot` too. Expect wall <=3 min.

## Branch protection — restore runbook (ACTIVE since 2026-11-19)

Current state 2026-11-19: ACTIVE (verified via API: six required checks,
`enforce_admins=true`, force-push/deletion blocked).

Branch protection is remote state, not Git. The 2026-11-11 audit found `main`
unprotected (`protected:false`, no rulesets, required checks empty): every gate
was advisory and force-pushes/deletions were allowed. Treat any settings change
as an incident and record evidence immediately.

Required checks (exact display names, unchanged from G0):

- `lint`, `build`, `test`, `coverage`, `db aggregate`, `coverage-pr`

Settings: strict off (D9), merge commits only, `enforce_admins` on, force-push
and deletion blocked, no review requirement (solo-owner flow), linear history
not required.

Restore with the full payload (the API rejects partial updates):

```sh
cat > /tmp/protection.json <<'JSON'
{
  "required_status_checks": {
    "strict": false,
    "contexts": ["lint", "build", "test", "coverage", "db aggregate", "coverage-pr"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": false,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON
gh api --method PUT repos/mfebriansyaaah/cobol-banking-core/branches/main/protection \
  --input /tmp/protection.json
```

Verify:

```sh
gh api repos/mfebriansyaaah/cobol-banking-core/branches/main/protection \
  --jq '{checks: .required_status_checks.contexts,
         enforce_admins: .enforce_admins.enabled,
         force_push: .allow_force_pushes.enabled,
         deletions: .allow_deletions.enabled}'
```

Evidence 2026-11-11: `protected=true`, six contexts as above,
`enforce_admins=true`, `force_push=false`, `deletions=false`.

Note: required checks must keep their exact display names. A renamed job makes
GitHub wait forever for a context that never reports — `check_ci_contract`
guards the names, and this runbook's verify step guards the remote state.
