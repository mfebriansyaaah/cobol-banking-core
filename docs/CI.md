# CI Status

> R0 readiness branch 00A. Single source of truth for CI triggers, required
> checks, cost, enforcement, and rollout. Last verified: 2026-11-04, commit
> `b92ee279`, by QA (tabletop, no Actions run — billing/access not verified).

## Current status: MANUAL-ONLY (parked)

All four workflows are `workflow_dispatch` only at HEAD:

| Workflow | File | Trigger at HEAD | Intended trigger | Status |
| --- | --- | --- | --- | --- |
| CI | `.github/workflows/ci.yml` | `workflow_dispatch` | `push: [main]`, `pull_request` | parked (commit `7e030110`) |
| Coverage | `.github/workflows/coverage.yml` | `workflow_dispatch` | `schedule 30 2 * * *` | parked (commit `1dfc11de`) |
| Nightly | `.github/workflows/nightly.yml` | `workflow_dispatch` | `schedule 0 2 * * *` | parked (commit `1dfc11de`) |
| CodeQL | `.github/workflows/codeql.yml` | `workflow_dispatch` | schedule (GHAS-gated) | manual until GHAS decision |

Exception: billing suspension aborts every run before it starts. A minimal
bridge workflow does **not** fix suspension. Owner: `@mfebriansyaaah`.
Review/expiry: 2026-11-18. If billing is still suspended, update this file and
do not claim automatic CI.

Badge policy: while parked, do not present the README CI badge as proof of a
green gate. The badge reflects the last manual run only.

## Trigger matrix (target, after unpark)

| Event | Workflow | Jobs |
| --- | --- | --- |
| `pull_request`, `push: [main]` | `ci.yml` | lint, build, test, db-shards (4), db-aggregate, coverage, coverage-pr |
| `push: [main]` | `ci.yml` post-merge | migration rollback, backup/restore, schema drift |
| nightly `0 2 * * *` | `nightly.yml` | full twice + drills + gateway coverage + load test + flake compare |
| nightly `30 2 * * *` | `coverage.yml` | full COBOL + gateway measurement |
| schedule/manual | `codeql.yml` | JS + C analysis (SARIF artifact while GHAS unavailable) |

Restore order: revert `7e030110` (PR/push), then `1dfc11de` (schedules).
Verify with a throwaway PR: lint fails on broken shell, build fails on broken
COBOL, db-aggregate fails on deleted assertion, post-merge runs on `main`,
nightly starts on schedule.

## Required checks

Phase 0 (before G0):

- `lint`
- `build`
- `test`
- `db-aggregate`
- `coverage`

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
| `ci.yml` coverage-pr | 45 min | curated COBOL, impact-selected |
| `ci.yml` post-merge | no timeout set | rollback, backup/restore, drift |
| `codeql.yml` analyze | 30 min | JS + C, SARIF artifact while GHAS unavailable |
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
gateway), probes, count gate, docs, schema drift, warnings, gateway coverage,
bench, drills, lint, security, offline tests, and the coverage mapper. It must
fail — not skip — when a tool is missing.

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
plus nightly can exceed it. If the budget is insufficient, reduce in this
order: db-shards only on DB/COBOL PRs; coverage/CodeQL/mutation nightly;
nightly 3×/week. Never remove lint/build/test/count/security from `main`.
Record actual minutes after two weeks and replace this table.
Owner approval required for the budget (R0 criterion 6).

## Enforcement

Current: private repository on GitHub Free; rulesets return HTTP 403
(see `docs/GOVERNANCE.md`). No server-side enforcement is active.

Plan (T-004 / T-054A):

1. Preferred: GitHub Pro or public repository + ruleset for `main`.
2. Fallback: GitHub App / merge bot that refuses to merge on red checks.
3. Last resort: manual policy + pre-push hook + reviewer checklist (caps 9/10
   at 8.5, with expiry).

Pre-push hook (`scripts/dev/install-hooks.sh`, wired via `bootstrap.sh`):

- Critical money path: `premerge.sh --ci-parity`.
- Other financial domains: `premerge.sh --all`.
- Docs-only: `premerge.sh` (fast).
- `SKIP_PREMERGE=1` only with a recorded reason; logged to
  `artifacts/premerge-skips.log`.

Required evidence before G0: ruleset screenshot or merge-bot run URL, plus a
deliberately red PR that cannot merge.

## Rollout and communication (T-047)

- Announce enforcement 5 working days before enabling required checks.
- Publish this file as the single source of truth.
- Hold two office hours in the first week.
- Publish weekly: pass rate, action coverage, coverage, open flake age,
  security findings, Actions minutes vs budget.
- Emergency hotfix: owner approval, `--ci-parity` waived only with a recorded
  reason, post-merge full run mandatory. Record the exception in the PR.

## R0 readiness (2026-11-04)

| # | Criterion | Status |
| --- | :--- | --- |
| 1 | Owner decisions signed | Partial — defaults in master plan 0.5, signatures pending |
| 2 | Billing fixed | Not met — no Actions run verified |
| 3 | Enforcement access verified | Not met — ruleset access not verified |
| 4 | Tooling pinned | Partial — `scripts/ci/tool-checksums.txt` added in 00B, SHAs pending first download |
| 5 | Branch-train dry-run | Not met — T-058 runs in 00B |
| 6 | Cost approved | Partial — estimate in this file, approval pending |
| 7 | Named owners | Not met — single owner, see `docs/OWNERSHIP.md` |
| 8 | Executor independence | Partial — tabletop pending second engineer |
| 9 | Communication ready | Met — this file + rollout above |
| 10 | Day 0 preflight | Not met — full suite not run in R0 |
| 11 | Branching plan | Met — `docs/BRANCHING.md` added in 00A |

R0 passes when 1–8, 10, 11 are Met. Current composite: 8.5/10.

## Branch-train dry-run (T-058, runs in 00B)

1. `chore/testing-r0-00-dry-run-1` — no-op doc line, PR, checks, rebase-merge, delete.
2. `chore/testing-r0-00-dry-run-2` — cut from updated `main`, repeat.
3. `git ls-remote --heads origin` must show only `refs/heads/main`.
4. Record PR URLs and the `ls-remote` output here.

Status: pending (00B).

## Known-red / preflight

Day 0 preflight has not been run in R0. Before Phase 0, run the section 0.4
commands and store the result under `artifacts/preflight-<short-sha>/`. If
red, list every suite in `docs/known-red.md` with owner, reason, and expiry.
