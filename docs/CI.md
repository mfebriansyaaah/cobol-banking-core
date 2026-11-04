# CI Status

> R0 readiness branch 00A. Single source of truth for CI triggers, required
> checks, cost, enforcement, and rollout. Last verified: 2026-11-04, commit
> `b92ee279`, by QA (tabletop, no Actions run — billing/access not verified).
> Owner sign-off: see “Owner sign-off (R0 criterion 1)” below.

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

Current (2026-11-04, verified): public repository; rulesets API accessible
(`gh api .../rulesets` returns `[]`, rc=0 — not 403). No ruleset is active yet;
active blocking plus red-PR proof is G0 (branch 02, T-004).

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

## R0 readiness (2026-11-04, updated in 00B)

| # | Criterion | Status |
| --- | :--- | --- |
| 1 | Owner decisions signed | Met — signed 2026-11-04, see below |
| 2 | Billing fixed | Met — run 41772256921 executes (build + 4 db-shards success, test in progress 2026-11-04); billing no longer aborts runs. Lint/coverage failures are pre-existing gates, not billing. |
| 3 | Enforcement access verified | Met — `gh api .../rulesets` returns `[]` rc=0 2026-11-04; draft in `.github/rulesets/main.json` valid (4 rules); active blocking is G0 |
| 4 | Tooling pinned | Met (binary SHAs) — `scripts/ci/tool-checksums.txt` verified 2026-11-04 for shellcheck, shfmt, actionlint, promtool, gitleaks; image digest + CodeQL/diff-cover deferred to Phase 1 |
| 5 | Branch-train dry-run | Met (local) — `chore/testing-r0-00-dry-run-1` (`e1c2cde8`) and `-2` (`2d9366fa`) merged to `main` and deleted; remote still only `main`; evidence in `docs/dry-run-proof.md` |
| 6 | Cost approved | Partial — estimate in this file, approval pending |
| 7 | Named owners | Met — `@get-money-first` added as backup on every path 2026-11-04; see `docs/OWNERSHIP.md` |
| 8 | Executor independence | Partial — single-engineer execution; tabletop pending second engineer |
| 9 | Communication ready | Met — this file + rollout above |
| 10 | Day 0 preflight | Not met — full suite not run in R0 |
| 11 | Branching plan | Met — `docs/BRANCHING.md` added in 00A |

R0 passes when 1–8, 10, 11 are Met. Current composite: 8.5/10.

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

### R0 sign-off (T-052, 2026-11-04) — NOT PASSED

R0 does **not** pass. Met: 1, 2, 3, 4, 5, 7, 9, 11. Not met: 10. Partial: 6, 8.
Phase 0 must not start until the blockers below are closed.

Proven 2026-11-04: run
`https://github.com/mfebriansyaaah/cobol-banking-core/actions/runs/41772256921`
executes (build success, db-shards 0–3 success, test in progress; lint fails at
Shell lint SC2164 in `scripts/test/run.sh`, coverage fails — both pre-existing,
triaged as G0/Phase 0, not billing).

Blockers and owners:

- Day 0 preflight (criterion 10) — must run full suite and triage red suites.
- Cost approval (criterion 6), second-engineer tabletop (criterion 8) —
  partial, need dates and approvers.

What 00A/00B delivered: branching plan, CI status source, ownership gap record,
cost estimate, rollout plan, main-protection draft + hook, tool checksums with
verified SHAs, local branch-train dry-run with only `main` on the remote.

Next: close the blockers above, then re-run T-052. Do not start Phase 0.

## Branch-train dry-run (T-058, done in 00B)

1. `chore/testing-r0-00-dry-run-1` — commit `e1c2cde8`, merged to `main` via
   fast-forward, deleted locally.
2. `chore/testing-r0-00-dry-run-2` — commit `2d9366fa`, merged to `main` via
   fast-forward, deleted locally.
3. `git ls-remote --heads origin` shows only `refs/heads/main` (verified
   2026-11-04; local branches never pushed, so remote was never polluted).
4. Evidence: `docs/dry-run-proof.md` plus `git log --oneline` showing both merges.

Status: done locally. Remote PR URLs: n/a (local-only dry-run; no remote branches created).

## R0 sign-off (T-052, 2026-11-04) — NOT PASSED, Phase 0 blocked

R0 composite remains 8.5/10. Do not start Phase 0. Re-run T-052 after billing,
enforcement access, second owners, cost approval, second-engineer tabletop,
and Day 0 preflight are closed.

## Known-red / preflight

Day 0 preflight has not been run in R0. Before Phase 0, run the section 0.4
commands and store the result under `artifacts/preflight-<short-sha>/`. If
red, list every suite in `docs/known-red.md` with owner, reason, and expiry.
