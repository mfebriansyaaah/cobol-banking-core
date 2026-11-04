# Governance and Merge Policy

> **CI status (2026-11-04):** automatic triggers restored in Phase 0 branch 01.
> See [CI status](CI.md). Required checks block merge; no admin bypass.

## Status

This repository is private and uses GitHub Free. GitHub rejects branch
protection and repository rulesets for this plan:

```text
403 Upgrade to GitHub Pro or make this repository public to enable this feature.
```

Because server-side enforcement is unavailable, this document records the
approved exception and the compensating controls that apply to every change.

## Exception

- **Exception:** `main` is not server-side protected.
- **Reason:** private repository on GitHub Free; branch protection and rulesets
  return HTTP 403.
- **Decision:** keep the repository private and enforce the policy locally and
  in CI.
- **Owner:** `@mfebriansyaaah`.
- **Review date:** revisit when the repository becomes public, the GitHub plan
  is upgraded, or the repository is prepared for external distribution.

The exception does not permit direct pushes or merges with red checks. It only
means the rule is enforced by process and automation rather than by GitHub's
merge button.

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

A pull request is not mergeable under this policy unless both jobs are green.
The GitHub UI cannot enforce that on the current plan; reviewers must verify it.

## CODEOWNERS

`.github/CODEOWNERS` assigns every path to `@mfebriansyaaah`. Expand the file
when additional maintainers join.

## Exceptions to this policy

Any exception must be recorded in the pull request description with:

- the reason,
- the risk,
- the compensating test or review,
- the approver.

Silent exceptions are not permitted.

## Upgrading to server-side enforcement

When the repository becomes public or the GitHub plan is upgraded:

1. Enable branch protection or a repository ruleset for `main`.
2. Require `build` and `test` status checks.
3. Require at least one approval and dismiss stale approvals.
4. Require CODEOWNERS review.
5. Block force pushes and deletions.
6. Remove the exception section from this document.
