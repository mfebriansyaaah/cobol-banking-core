# Ownership

> Second owner named 2026-11-04: `@get-money-first`. Bus factor 1 closed for R0.
> Exception cap 8.5 is lifted for ownership; review date 2026-12-04 stays for
> onboarding proof.

## Current state (2026-11-04)

| Critical path | Primary owner | Backup owner | Status |
| --- | --- | --- | --- |
| COBOL core (`cobol/`) | @mfebriansyaaah | @get-money-first | OK |
| Gateway (`middleware/`) | @mfebriansyaaah | @get-money-first | OK |
| Database / migrations (`database/`) | @mfebriansyaaah | @get-money-first | OK |
| Tests / CI (`tests/`, `scripts/`, `.github/`) | @mfebriansyaaah | @get-money-first | OK |
| Security (SAST, secrets, audit) | @mfebriansyaaah | @get-money-first | OK |
| Docs (`docs/`) | @mfebriansyaaah | @get-money-first | OK |

`.github/CODEOWNERS` assigns every path to `@mfebriansyaaah` with
`@get-money-first` as backup (verified 2026-11-04).

## History

The single-maintainer exception (2026-11-04) was closed when `@get-money-first`
was added to every path in `.github/CODEOWNERS`. The onboarding tabletop
remains tracked in T-044.

## Escalation

1. PR author requests review from the primary owner.
2. If no response in 1 business day, ping in the PR and in the weekly review.
3. If no response in 2 business days, the repository owner (`@mfebriansyaaah`)
   may assign a temporary reviewer and record it in the PR.
4. Money-path changes (wallet, auth, payments, treasury, GL, settlement)
   require two approvals. A single approval is never sufficient for those
   paths, even under time pressure.

## Review SLA

- Docs/config-only: 1 business day.
- Test-only: 2 business days.
- Money-path or migration: 2 business days + second reviewer.
- Security: same-day triage, fix or time-boxed exception within 3 days.

## Onboarding

A new engineer runs, in order:

```sh
make bootstrap
make test-fast
DB_NAME=cobol_db_premerge bash scripts/ci/premerge.sh --ci-parity
```

The onboarding is complete when the engineer can add a table case, run the
targeted suite, and explain how to update `tests/baseline_counts.txt` without
hand-editing numbers. Record the tabletop in the PR that closes T-044.
