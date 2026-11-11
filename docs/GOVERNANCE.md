# Governance and Merge Policy

> **CI status (2026-11-04):** automatic triggers restored in Phase 0 branch 01.
> Branch protection active on `main` since branch 02 (required checks, 1
> approval + CODEOWNERS, merge commits, no force push, no bypass).
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
4. **Review.** At least one approval is required (enforced by branch
   protection together with code-owner review). The two-approvals-for-money-paths
   aspiration cannot be satisfied by two distinct people while the project
   has a solo human maintainer, so money-path PRs (wallet, auth, payments,
   treasury, GL, settlement) operate under the solo rule instead:
   the enforced code-owner approval, plus a recorded author second pass in
   the PR body, plus green money-path gates (equivalence + mutation suites
   in CI). See the exception below and `docs/OWNERSHIP.md` (expiry
   2026-12-04).
5. **Code owners.** Changes must be reviewed by the owner listed in
   `.github/CODEOWNERS`.
6. **No admin bypass.** The owner must not merge with failing checks even
   though GitHub would allow it.
7. **Small PRs.** Prefer under 1.500 changed lines; >1.500 requires a recorded
   exception — see `docs/BRANCHING.md`. Split domain waves and refactors
   into reviewable units.
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
(`lint`, `build`, `test`, `db aggregate`, `coverage`, `coverage-pr`) are green. GitHub
enforces this on `main` via branch protection; reviewers still verify the
evidence.

CodeQL (`codeql.yml`, PR/push/schedule) scans the JavaScript gateway and the
C crypto helpers (`cobol/c_lib`); COBOL is out of scope (no extractor
exists). CodeQL is informational, not a required check, until one green run
plus an alert-triage pass; it becomes required only if the owner accepts
security findings as merge blockers.

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

### Standing exception: money-path second human reviewer (accepted 2026-11-07, expiry 2026-12-04)

- Reason: solo human maintainer; the two-distinct-approvals rule for money
  paths cannot be satisfied.
- Compensating controls: (a) the enforced 1 code-owner approval operates on
  every PR — audited 2026-11-07, PRs #567, #572, #574, #577, #580, #581,
  #584, #586, #589, #590, #592, #593, #594, #595 all carry the
  `@get-money-first` approval (query: `gh pr view <n> --json reviews`);
  (b) author second pass recorded in money-path PR bodies; (c) automated
  money-path gates (equivalence + mutation suites) green in CI before merge.
- Approver: `@mfebriansyaaah`.
- Expiry: 2026-12-04, shared with the ownership exception in
  `docs/OWNERSHIP.md`. Revisit when a second human reviewer joins.

## Enforcement notes

Branch protection is configured via the classic Branch Protection API
(equivalent to a ruleset here: repository rulesets on this plan reject the
`pull_request` and `required_status_checks` rule types, verified 2026-11-04).
Revisit rulesets if the plan upgrades. Current settings on `main`:

- required status checks `lint`, `build`, `test`, `db aggregate`, `coverage`,
  `coverage-pr` (not strict: passing checks are required, an up-to-date
  branch is not), enforced for admins;
- 1 approval, dismiss stale reviews, CODEOWNERS review required;
- merge commits (squash/rebase merging disabled), force pushes and branch deletion blocked.
