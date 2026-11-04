# Governance and Merge Policy

> **CI status (2026-11-04):** automatic triggers restored in Phase 0 branch 01.
> Branch protection active on `main` since branch 02 (required checks, 1
> approval + CODEOWNERS, linear history, no force push, no bypass).
> See [CI status](CI.md).

## Status

This repository is public. Branch protection on `main` is active and enforced
by GitHub (verified 2026-11-04 via API). No exception is in effect.

History: the repository was private on GitHub Free, where branch protection
and rulesets returned HTTP 403; enforcement was local-only during R0. That
exception is closed.

## Required controls

Every change to `main` must satisfy all of the following:

1. **Pull request only.** No direct push to `main`.
2. **Green CI.** The GitHub Actions `build` and `test` jobs must pass.
3. **Local pre-merge gate.** `bash scripts/ci/premerge.sh` must pass on the
   exact commit being merged.
4. **Review.** At least one approval is required. Two approvals are required
   for money paths: wallet, auth, payments, treasury, GL, and settlement.
5. **Code owners.** Changes must be reviewed by the owner listed in
   `.github/CODEOWNERS`.
6. **No admin bypass.** The owner must not merge with failing checks even
   though GitHub would allow it.
7. **Small PRs.** Prefer under 500 changed lines. Split domain waves and
   refactors into reviewable units.
8. **No secrets or real PII.** Use placeholders in examples and fixtures.

## Local enforcement

Run before opening or updating a pull request:

```sh
bash scripts/ci/premerge.sh
```

The script runs the static gates and the fast suite by default; probes, the
docs gate, and the full suite are opt-in (`--probes`, `--docs`, `--full`).
CI additionally runs the DB, integration, fuzz, migration-rollback,
backup-restore, schema-drift, and performance suites through `tests/run_all.sh full`.

## CI enforcement

`.github/workflows/ci.yml` runs on every pull request and on pushes to `main`.
The `build` job runs the manifest check, probes, SAST, build, and warning
ratchet. The `test` job runs the full test gate (fast + DB + integration +
error harness + gateway suites), the assertion count gate, migration
rollback drill, backup and restore drill, schema drift check, and performance benchmarks.

A pull request is not mergeable under this policy unless the required checks
(`lint`, `build`, `test`, `db aggregate`, `coverage`) are green. GitHub
enforces this on `main` via branch protection; reviewers still verify the
evidence.

## CODEOWNERS

`.github/CODEOWNERS` assigns every path to `@mfebriansyaaah` with
`@get-money-first` as backup reviewer. Expand the file when additional
maintainers join.

## Exceptions to this policy

Any exception must be recorded in the pull request description with:

- the reason,
- the risk,
- the compensating test or review,
- the approver.

Silent exceptions are not permitted.

## Enforcement notes

Branch protection is configured via the classic Branch Protection API
(equivalent to a ruleset here: repository rulesets on this plan reject the
`pull_request` and `required_status_checks` rule types, verified 2026-11-04).
Revisit rulesets if the plan upgrades. Current settings on `main`:

- required status checks `lint`, `build`, `test`, `db aggregate`, `coverage`
  (strict), enforced for admins;
- 1 approval, dismiss stale reviews, CODEOWNERS review required;
- linear history, force pushes and branch deletion blocked.
