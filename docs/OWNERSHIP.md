# Ownership

> R0 readiness branch 00A. Single owner today; second owners required for 9/10.
> Review date: 2026-12-04 or when a second owner is named, whichever is first.

## Current state (2026-11-04)

| Critical path | Primary owner | Backup owner | Status |
| --- | --- | --- | --- |
| COBOL core (`cobol/`) | @mfebriansyaaah | — | backup missing |
| Gateway (`middleware/`) | @mfebriansyaaah | — | backup missing |
| Database / migrations (`database/`) | @mfebriansyaaah | — | backup missing |
| Tests / CI (`tests/`, `scripts/`, `.github/`) | @mfebriansyaaah | — | backup missing |
| Security (SAST, secrets, audit) | @mfebriansyaaah | — | backup missing |
| Docs (`docs/`) | @mfebriansyaaah | — | backup missing |

`.github/CODEOWNERS` assigns every path to `@mfebriansyaaah`. That matches
reality today but leaves bus factor 1.

## Required second owners (blocks 9/10)

At least two named owners per critical path are required for the 9/10
ownership criterion. Until they are named:

- 9/10 is capped at **8.5/10** (see master plan section 0.5).
- The exception owner is `@mfebriansyaaah`.
- Expiry: 2026-12-04. Revisit when a second owner joins or the repository
  becomes public.

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
