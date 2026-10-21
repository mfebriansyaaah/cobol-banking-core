# Delivery rules and volume target

Status: **mandatory**, effective 2026-10-21. Owner: repository owner.
This file is the single source of truth for how a slice is delivered. If any
other document conflicts with it, this file wins.

The rules exist to keep one-day throughput high without padded, duplicated, or
generated code. They replace the old sprint plan, per-commit push rule, and
`HISTORY.md` ceremony.

## 1. Mandatory slice rules

1. **One PR = two modules.** A module is a curated COBOL domain with schema,
   actions, gateway routes, and tests. A docs-only or schema-only change does
   not count as a module. Target **5.000-6.500 net** per PR.
   - Below 4.000 net: record the reason in the PR.
   - Above 7.000 net: split into two PRs unless the owner approves a one-off.
2. **One full CI, one push.** Commit atomically per module, run targeted tests
   locally, then push the branch **once** after `./ci.sh` is green. Open one PR.
   Do not push every commit and do not use a draft PR for iteration.
3. **Interface freeze (15 minutes).** Before writing code, put a freeze note in
   the PR body: tables/columns, actions and params, error codes, routes, test
   matrix, and expected net. No interface changes after implementation starts;
   if one is unavoidable, stop and re-freeze.
4. **Parallel by default.** After the freeze, independent modules run in
   separate worktrees/subagents. One integrator merges them into the slice
   branch. No direct commits to `main`.
5. **Table-driven tests.** Each module gets one `tests/test_<module>.sh` with
   one setup and a table of cases. Wire the suite into `ci.sh` and
   `tests/baseline_counts.txt` in the same PR. Do not repeat setup boilerplate
   per assertion.
6. **Finalize before CI.** Run `./scripts/finalize_slice.sh` before the full
   gate. It updates the non-generated baseline and the documented headline
   counts, then checks docs/status/traceability. `./ci.sh` remains the merge
   gate.
7. **One review.** Open the PR only after CI is green. Review once; fix findings
   in one commit series. Do not expand scope or request a second review for a
   different slice in the same PR.
8. **No volume inflation.** No generated `ref_core` growth, blank/comment
   padding, duplicate paragraphs, dead actions, unused copybooks, or copied
   boilerplate. curated COBOL only; the long-term COBOL share is at least 50%.
9. **One open PR at a time.** Merge the previous slice before starting the next.
   `./scripts/sync_main.sh` prepares the next branch.
10. **Definition of done:** freeze note, two modules, migrations, actions,
    routes, table-driven tests, docs, baselines, full CI, coverage, warning
    ratchet, and a single review. A slice missing any one of these is not done.

## 2. Volume target

Metric: **non-generated net code** (non-blank, non-comment, tracked files;
`docs/`, lockfiles, `cobol/src/generated/`, and `@generated` files excluded).
Executable shell and JavaScript tests count because they are evidence.

Current baseline measured 2026-10-21 after the GL and batch/EOD slices:

| Component | Net lines |
|---|---:|
| Curated COBOL | 13.191 |
| C and header | 1.179 |
| SQL | 4.708 |
| Shell | 22.519 |
| JavaScript | 11.494 |
| **Total non-generated** | **53.091** |
| COBOL share | 24,8% |

Target:

| Metric | Target |
|---|---:|
| Non-generated net | **100.000** |
| Total COBOL floor | **>= 60.000** |
| Curated COBOL | **>= 50.000** |
| COBOL share | **>= 50%** |
| Remaining gap | **46.909** |

Workstream budget (curated COBOL):

| Workstream | Net COBOL |
|---|---:|
| GL expansion | 10.000 |
| Batch/EOD | 9.000 |
| Reports and statements | 8.000 |
| Payments, holds, fees, limits | 7.000 |
| Reference engine expansion | 4.500 |
| Auth, user, disputes | 3.500 |
| Import/export and migration | 3.500 |
| **Total** | **45.500** |

About 4.800 net non-COBOL covers gateway routes, SQL migrations/views, and
integration tests. The metric is a volume constraint, not a production-readiness
claim; correctness, security, reliability, data governance, and owner approvals
remain the release gates.

## 3. Current slice queue

Sprint 1 has delivered GL period/multi-line journals (533 net) and the
batch/EOD foundation (2.769 net). The next two-module slices are:

1. Report engine + import/export.
2. Real EOD jobs (fee/hold/dormant/statement) + fee/limit/velocity rules.
3. Reference engine expansion + auth/user/dispute gaps.
4. Payments hardening + reconciliation/reporting.

Each slice must follow the rules above. A one-day result is measured in
**merged, tested net**, not in raw editor output.

## 4. Enforcement

- `./scripts/finalize_slice.sh` - updates baselines and documented counts.
- `./ci.sh` - full gate; must end `ALL GREEN`.
- `./tests/status_check.sh` - docs/count consistency.
- `./tests/docs_check.sh` and `./tests/traceability_check.sh` - docs and owner
  evidence integrity.
- `./scripts/loc_report.sh --non-generated --check` - volume ratchet.
- `./scripts/loc_report.sh --check-floor` - COBOL floor and curated share.

Breaking a rule is a stop condition, not a style note.
