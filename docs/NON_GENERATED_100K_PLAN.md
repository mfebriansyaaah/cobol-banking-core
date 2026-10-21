# Non-generated 100k plan

Status: active engineering plan. Owner approvals remain in
`docs/APPROVALS.md`; this plan tracks implementation volume only.

## 1. Metric

**Non-generated net code** is the net (non-blank, non-comment) line count of
tracked code files, excluding:

- `docs/` and Markdown;
- lockfiles;
- `cobol/src/generated/` and files marked `@generated`.

The metric includes shell tests and JavaScript tests because they are part of
the repository's executable evidence. If the owner wants a **product-only**
100k (tests excluded), that is a different and larger target; it needs a
separate decision.

## 2. Baseline (2026-10-21)

| Component | Net lines |
|---|---:|
| Curated COBOL | 11.012 |
| C and header | 1.179 |
| SQL | 4.469 |
| Shell | 22.281 |
| JavaScript | 11.289 |
| **Total non-generated** | **50.230** |
| COBOL share | 21,9% |

This is +533 lines over the 49.697 baseline recorded when the plan merged:
GL period open/close control, multi-line journals, the period migration, the
expanded 22-assertion GL suite, and the gateway error mapping. The baseline
file is `tests/non_generated_baseline.txt`.

## 3. Target

| Metric | Target |
|---|---:|
| Non-generated net | **100.000** |
| Curated COBOL net | **>= 50.000** (minimum) |
| Recommended curated COBOL | **56.065** |
| Recommended non-COBOL | 43.935 |
| COBOL share | **>= 50%** (recommended 56%) |

Recommended additions (original budget): **+45.500 COBOL +4.803 other =
+50.303**. At the current 50.230 baseline this leaves a 533-line buffer over
100.000; the remaining gap is **49.770**.

## 4. Workstream budget

| Workstream | Net COBOL addition | Scope |
|---|---:|---|
| GL expansion | 10.000 | period close, multi-line journals, subledger-to-GL mapping, FX revaluation, trial-balance reports |
| Batch/EOD | 9.000 | job registry, checkpoint/restart, fee/hold/dormant/statement batches, control totals |
| Reports and statements | 8.000 | report writer, generic reports, notices, CSV/fixed-width |
| Payments, holds, fees, limits | 7.000 | fee engine, limit profiles, velocity, hold policy, hardening |
| Reference engine expansion | 4.500 | translations, hierarchy, import/export, effective dating |
| Auth, user, disputes | 3.500 | step-up, access review, dispute SLA, notifications |
| Import/export and migration | 3.500 | CSV/fixed-width import, staging, validation, posting, error reports |
| **Total** | **45.500** | |

Add about **4.800 net non-COBOL** for gateway routes, SQL migrations/views,
and integration/shell tests.

## 5. Sprint plan (10-12 weeks)

| Sprint | Weeks | COBOL addition | Focus |
|---|---:|---:|---|
| 1 | 1-3 | 14.000 | GL expansion and batch/EOD foundation |
| 2 | 4-6 | 13.000 | batch jobs, reports and statements |
| 3 | 7-9 | 15.000 | payments/fees/limits, reference engine, auth/user/disputes |
| 4 | 10-12 | 3.500 | import/export, hardening, full CI, 100k verification |

At 1.200-1.500 net curated COBOL per day, the sprint plan is 8-10 weeks of
engineering; review, CI, and stabilization make 10-12 weeks the realistic
range. A 2-4 week result would require padding or generated code, which this
metric excludes.

## 6. Per-PR rules

1. Report the delta with:
   `./scripts/loc_report.sh --non-generated`
2. Never lower `tests/non_generated_baseline.txt`; raise it when curated code
   grows.
3. No generated code, blank/comment padding, duplicate paragraphs, dead
   actions, or copied boilerplate.
4. Add before delete; cutovers may reduce generated code but must add curated
   behavior in the same or a follow-up PR.
5. Full `./ci.sh` green; coverage ratchet; `--check-floor` green.
6. Keep the COBOL share target visible; if the new COBOL share falls below 50%
   of the non-generated total, stop and rebalance.

## 7. Tracking

```sh
./scripts/loc_report.sh --non-generated
./scripts/loc_report.sh --non-generated --check
```

Expected after the plan: total >= 100.000, curated COBOL >= 50.000, COBOL
share >= 50%.

## 8. What does not help

- Adding generated `ref_core` entities: excluded by the metric.
- Cutting over a generated domain: moves lines but adds little net volume.
- Blank lines, comments, duplicated paragraphs, or dead code: excluded or
  rejected by review.
- Counting docs, lockfiles, or generated files: not part of this metric.

## 9. First actions

1. Run the non-generated baseline and keep it in CI-adjacent checks.
2. Start Sprint 1 with **GL expansion** and **batch/EOD foundation**.
3. Update `tests/non_generated_baseline.txt` after each merged slice.
4. Re-plan if the COBOL share or the floor is at risk.

## 10. Relationship to the production-grade plan

This plan extends `docs/PRODUCTION_GRADE_PLAN.md`; it does not replace the
production workstreams. The 100k non-generated target is a volume constraint,
not a production-readiness claim. Correctness, security, reliability, data
governance, and owner approvals remain the release gates.
