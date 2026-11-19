# CI SLO

| Metric                         | Target            |                Measured by |
| ------------------------------ | ----------------- | -------------------------: |
| PR p50 wall clock              | <= 12 min         |                  ci-report |
| PR p95 wall clock              | <= 20 min         |                  ci-report |
| PR failure rate                | <= 25%            |                  ci-report |
| Push failure rate              | <= 10%            |                  ci-report |
| PR p50 job-min                 | <= 22 job-min     |                  ci-report |
| Push p50 job-min               | <= 18 job-min     |                  ci-report |
| Failed-run waste               | <= 8%             |                  ci-report |
| Monthly job-min (30d)          | <= 10.000 job-min | ci-report (`ci-cost.json`) |
| Billing incident               | 0                 |                     manual |
| Nightly success                | >= 90%            |                  ci-report |
| Coverage scheduled success     | >= 90%            |                  ci-report |
| Mutation scheduled success     | >= 80%            |                  ci-report |
| Time to triage nightly failure | <= 1 working day  |            issue timestamp |
| Flake rate                     | < 2%              |       compare_runs/nightly |

SLOs are evaluated every Monday by `.github/workflows/ci-report.yml`
(`scripts/ci/ci_weekly_report.mjs`). A breach opens or updates the
`ci-health` issue (`scripts/ci/ci_health_issue.sh`); a green report closes
it. See [CI](CI.md) for the trigger matrix and job inventory.
