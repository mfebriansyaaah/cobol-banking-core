# CI Status

> R0 readiness branch 00A. Single source of truth for CI triggers, required
> checks, cost, enforcement, and rollout. Last verified: 2026-11-04.
> Phase 0 branch 01 restores automatic triggers; see “Current status” below.

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
| `pull_request`, `push: [main]` | `ci.yml` | lint, build, test, db-shards (4), db-aggregate, coverage, coverage-pr |
| `push: [main]` | `ci.yml` post-merge | migration rollback, backup/restore, schema drift |
| nightly `0 2 * * *` | `nightly.yml` | full twice + drills + gateway coverage + load test + flake compare |
| nightly `30 2 * * *` | `coverage.yml` | full COBOL + gateway measurement |
| `pull_request`, `push: [main]`, schedule, manual | `codeql.yml` | JS + C analysis, SARIF uploaded to code scanning |

Restore order: revert `7e030110` (PR/push), then `1dfc11de` (schedules).
Verify with a throwaway PR: lint fails on broken shell, build fails on broken
COBOL, db-aggregate fails on deleted assertion, post-merge runs on `main`,
nightly starts on schedule.

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
| `ci.yml` lint | 15 min | shellcheck, eslint, prettier, markdownlint, actionlint, yamllint, promtool, semgrep, gitleaks, gate unit tests, npm audit |
| `ci.yml` build | 20 min | manifest, docs, complexity snapshot, probes, SAST, build, warning ratchet |
| `ci.yml` test | 30 min | full gate minus DB matrix, benchmarks, drills, drift |
| `ci.yml` db-shards (×4) | 30 min each | one shard per runner |
| `ci.yml` db-aggregate | 15 min | merge + inventory + count gate + summary |
| `ci.yml` coverage | 20 min | gateway-only |
| `ci.yml` coverage-pr | 45 min | curated COBOL, impact-selected (trigger groups in `docs/COVERAGE.md`) |
| `ci.yml` post-merge | 20 min | rollback, backup/restore, drift |
| `codeql.yml` analyze | 30 min | JS + C, SARIF uploaded to code scanning |
| `coverage.yml` | 45 min | full COBOL + gateway |
| `nightly.yml` | 180 min | full twice + drills + coverage + load + flake compare |

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

## Cost plan (planning ceiling, replace after 2 weeks)

| Workload | Assumption | Job-minutes/month |
| --- | --- | ---: |
| PR gate | 190 job-min × 20 PRs | 3,800 |
| Main push | 210 job-min × 20 pushes | 4,200 |
| Nightly full + coverage + load | 300 job-min × 30 nights | 9,000 |
| Mutation/CodeQL weekly | 120 job-min × 4 weeks | 480 |
| Buffer 30% | — | +5,244 |
| **Estimated total** | — | **~22,700 minutes/month** |

Private GitHub Free has a limited monthly minute quota; a 4-shard DB matrix
plus nightly can exceed it. While the repository is temporarily public,
Actions usage is free within fair-use limits, so this ceiling is a planning
number, not a billing blocker. If the budget is insufficient, reduce in this
order: db-shards only on DB/COBOL PRs; coverage/CodeQL/mutation nightly;
nightly 3×/week. Never remove lint/build/test/count/security from `main`.
Record actual minutes after two weeks and replace this table.

Approved 2026-11-04 by `@mfebriansyaaah`: ceiling ~22,700 minutes/month
accepted as planning number; re-approve with measured minutes before
re-privatizing the repository.

## Enforcement

ACTIVE since branch 02 (2026-11-04, verified via API): branch protection on
`main` requires `lint`, `build`, `test`, `db aggregate`, `coverage`,
`coverage-pr` (strict),
1 approval with stale-review dismissal, CODEOWNERS review, linear history;
force pushes, branch deletion, and admin bypass are blocked. Red-PR proof is
recorded below.

Naming trap (burned us on PR #510): GitHub matches the check-run **name**
(`db aggregate`, with space — the job `name:`), not the job ID
(`db-aggregate`). Requiring the hyphen form blocks every PR forever.

CI-002 evidence (2026-11-05): `coverage-pr` added to required status checks
via API (`required_status_checks/contexts`: `lint`, `build`, `test`,
`coverage`, `db aggregate`, `coverage-pr`; strict). Red-proof: PR #532
(`ci/ci-p0-02-red-proof`, COBOL floor forced to 100) failed `coverage-pr`
and showed `mergeStateStatus: BLOCKED`; closed unmerged, branch deleted.
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
  reason, post-merge full run mandatory. Record the exception in the PR.

## R0 readiness (2026-11-04, updated in 00B)

| # | Criterion | Status |
| --- | :--- | --- |
| 1 | Owner decisions signed | Met — signed 2026-11-04, see below |
| 2 | Billing fixed | Met — run 41772256921 executes (build + 4 db-shards success, test in progress 2026-11-04); billing no longer aborts runs. Lint/coverage failures are pre-existing gates, not billing. |
| 3 | Enforcement access verified | Met — `gh api .../rulesets` returns `[]` rc=0 2026-11-04; draft in `.github/rulesets/main.json` valid (4 rules); active blocking is G0 |
| 4 | Tooling pinned | Met (binary SHAs) — `scripts/ci/tool-checksums.txt` verified 2026-11-04 for shellcheck, shfmt, actionlint, promtool, gitleaks; image digest + CodeQL/diff-cover deferred to Phase 1 |
| 5 | Branch-train dry-run | Met (local) — `chore/testing-r0-00-dry-run-1` (`e1c2cde8`) and `-2` (`2d9366fa`) merged to `main` and deleted; remote still only `main`; evidence in `docs/dry-run-proof.md` |
| 6 | Cost approved | Met — ceiling ~22,700 min/month approved 2026-11-04 by `@mfebriansyaaah`; re-approve with measured minutes before re-privatizing |
| 7 | Named owners | Met — `@get-money-first` added as backup on every path 2026-11-04; see `docs/OWNERSHIP.md` |
| 8 | Executor independence | Met — tabletop 2026-11-04 by `@mfebriansyaaah` + `@get-money-first`, see `docs/tabletop-r0.md` |
| 9 | Communication ready | Met — this file + rollout above |
| 10 | Day 0 preflight | Met (triaged) — full serial run 2026-11-04: 271/273 DB green; 2 env failures triaged in `docs/known-red.md`; integration/gateway/smoke/harness/fuzz green; no orphans; artifacts in `artifacts/preflight-b6e4d7ce/` |
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
- Action coverage denominator: all 2,780 route actions (2026-11-04); HTTP-only
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
4. Evidence: `docs/dry-run-proof.md` plus `git log --oneline` showing both merges.

Status: done locally. Remote PR URLs: n/a (local-only dry-run; no remote branches created).

## R0 final record (T-052, 2026-11-04) — PASSED

R0 **passes** 2026-11-04. Met: 1–11 (criterion 10 triaged via `known-red.md`).
Composite: 9.0/10. Phase 0 may start with branch 01.

## Known-red / preflight

Day 0 preflight done 2026-11-04 (triaged, not green): see `docs/known-red.md`
and `artifacts/preflight-b6e4d7ce/`. Before Phase 0, re-run the section 0.4
commands on a provisioned database (Docker 3307) and confirm zero red, or carry
the two env entries with owner and expiry.
