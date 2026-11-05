# Branching and Merge Model

> R0 readiness branch 00A. Source of truth for how every change in the
> testing master plan reaches `main`. If this document and the master plan
> disagree, the master plan section 4.6 wins and this file must be updated.

## Model

Trunk-based development with a **serial merge train**.

- `main` is the only long-lived branch and is always releasable.
- Every change goes through a short-lived branch + PR, then merges to `main`.
- No `develop`, `staging`, `production`, or permanent `integration/*` branches.
- When all work is done, only `main` remains as a branch on the remote
  (`git ls-remote --heads origin` shows exactly one line).

Why trunk-based: the fleet has 274 DB suites, 2,780 route actions, and 657
migrations. Long-lived branches diverge the schema, baselines, and generated
snapshots within days. A serial train keeps `schema.sql`, `baseline_counts.txt`,
`route_field_order.json`, and the manifest coherent.

## Branch types

| Type | Pattern | Base | Lifetime | Protection |
| --- | --- | --- | --- | --- |
| Work | `<type>/testing-p<0-2>-<nn>-<slug>` | `main` | ≤5 working days | PR checks + approval |
| Readiness | `chore/testing-r0-00a-policy`, `chore/testing-r0-00b-tooling-dryrun` | `main` / previous readiness branch | ≤10 working days, docs/config/evidence only | PR checks + owner sign-off |
| Release (optional) | `release/<major.minor>` | tag / `main` | only while supported | same as `main`, owner-only |
| Hotfix | `hotfix/<version>-<slug>` | production tag or `main` | ≤2 working days | same as `main`, two approvals for critical money path |
| Temporary integration | `integration/testing-<milestone>` | `main` | ≤3 working days, owner approval required | owner approval, must be deleted |

`<type>` is `chore`, `fix`, `test`, `ci`, `docs`, `perf`, or `ops`.
`<nn>` is the two-digit train sequence from the master plan section 4.6.3.

## Serial merge train

Full table lives in the master plan section 4.6.3. Summary of the rule:

1. Branch N is cut from `main` **after branch N-1 is merged**, unless it is
   explicitly marked parallel-safe.
2. Parallel-safe branches are cut from the **group-start** `main` (the branch
   before the group), not from each other. Rebase on the merged partner before
   merge. Merge in table order.
3. Current parallel-safe groups: 03+04, 12+13, 14+15, 16+17.
4. Readiness exception: 00A/00B may live up to 10 working days while owner
   decisions are pending, but must contain docs/config/evidence only.

R0 train:

- 00A `chore/testing-r0-00a-policy` — policy, branching, CI status, ownership, cost, rollout, main protection
- 00B `chore/testing-r0-00b-tooling-dryrun` — tool checksums, branch dry-run, R0 sign-off

## Commit sequence

Each branch must contain a coherent sequence: **test/gate first,
implementation second, baseline/evidence third, docs last**.

Format: `<area>(T-XXX): <imperative subject>`, for example:

```text
test(T-022): add wallet balance conservation
fix(T-022): enforce balance check before debit
docs(T-022): record invariant evidence
```

Rules:

- One branch = one coherent task group.
- Maximum diff: 500 changed lines excluding generated fixtures/docs.
- A commit that only fixes a previous commit in the same branch must be
  squashed with `git rebase -i` before merge.
- Every commit should keep the tree buildable if practical. At minimum the PR
  head must be green.
- Revert individual commits or the PR commit range. Never `git reset` or
  force-push `main`.

## Merge method

- Rebase the branch on `origin/main` before opening/updating the PR:

  ```sh
  git fetch origin
  git rebase origin/main
  git push --force-with-lease
  ```

- Use **Rebase and merge** in GitHub. Disable squash and merge commits for
  this work.
- Delete the remote branch immediately after merge:

  ```sh
  git push origin --delete <branch>
  git fetch --prune
  ```

- If the branch conflicts: rebase, do not merge `main` into the branch. If
  conflict resolution changes behavior, add a test and re-run the branch merge
  gate.

## Release, tag, hotfix

- Release: tag `v<major>.<minor>.<patch>` from a green `main`; run build +
  full test + drills on the tag.
- Release branch is optional and only for supported versions that need
  backports. Delete it at end-of-life.
- Hotfix: branch from the production tag (or `main` if `main` is the
  production commit), minimal fix, full gate, tag patch version,
  merge/cherry-pick to `main`, delete branch.
- Hotfix requires owner approval and two approvals for critical money path:
  wallet, auth, payments, treasury, GL, settlement.
- Never create `staging` or `production` branches. Environments are deployed
  from tags/commits, not branches.

## Branch protection

| Branch | Required | Approvals | Force push | Delete after merge |
| --- | --- | --- | --- | --- |
| `main` | All required checks, linear history, CODEOWNERS | 1; 2 for critical money path | Blocked | n/a |
| work branch | PR checks | 1 | Allowed to owner | Yes |
| `release/*` | All required checks | 1 + owner | Blocked | At EOL |
| `hotfix/*` | All required checks | 1; 2 for money path | Blocked | Yes |
| `integration/*` | Owner-approved checks | 1 + owner | Blocked | Before sign-off |

Current status (2026-11-04): repository is private on GitHub Free; rulesets
return HTTP 403. Until GitHub Pro/public or a merge bot is approved, enforce
with the pre-push hook (`scripts/dev/install-hooks.sh`) plus reviewer
checklist in `docs/CI.md`. Record the exception in `docs/CI.md` with owner,
reason, and expiry. 9/10 is capped at 8.5 without server-side or merge-bot
enforcement.

Required checks (Phase 0): `lint`, `build`, `test`, `db-aggregate`,
`coverage`, `coverage-pr`. `security` joins after WP-1.4.

## Final remote cleanup

After the last train branch is merged:

```sh
git fetch --prune
git ls-remote --heads origin
# Expected: exactly one line:
# <sha> refs/heads/main
```

Delete any leftover:

```sh
git push origin --delete <branch>
```

Tags are allowed and are not branches:

```sh
git ls-remote --tags origin
```

If the owner requires only `main` as a ref, delete tags after recording the
audit evidence; otherwise keep annotated release tags.

## Rollback

- Revert the PR commit range (`git revert <range>`); never reset `main`.
- If the train breaks `main`, pause the train, revert, then resume.
- If a branch grows beyond 5 days or 500 lines, split it rather than keeping
  it alive.
- For emergency hotfix, branch from the production tag/`main`, run the full
  gate, merge, tag, then resume the train.
- Do not create a long-lived integration branch to stabilize the train.
