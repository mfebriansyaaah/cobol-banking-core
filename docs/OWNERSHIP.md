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

## Formal exception (accepted 2026-11-04, resolved 2026-11-04)

- Reason: single maintainer; no second owner available yet.
- Risk: bus factor 1; reviews depend on one person; money-path two-approval
  rule cannot be satisfied by two distinct people.
- Compensating controls: CODEOWNERS review required on every PR; pre-push hook
  (`scripts/dev/install-hooks.sh`); weekly review of open PRs; no admin bypass;
  money-path PRs get extra scrutiny and a recorded second pass (self-review
  checklist in the PR body).
- Approver: `@mfebriansyaaah`.
- Expiry: 2026-12-04. R0 criterion 7 stays Not met; 9/10 stays capped at 8.5
  until a second owner is named.

## Resolution (2026-11-04)

Second owner `@get-money-first` (verified via `gh api users/get-money-first`)
added to every path in `.github/CODEOWNERS` and as backup in the table above.
Ownership cap is lifted. Remaining step (T-044): onboarding tabletop with the
second engineer; record it in the PR that closes T-044.

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
