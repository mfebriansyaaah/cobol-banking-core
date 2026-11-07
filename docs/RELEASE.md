# Release Checklist (PR-073)

Every production release follows this list in order. Skip nothing silently;
check the box in the release PR.

## Prepare

- [ ] Version bump (semver; `CHANGELOG.md` entry with user-visible changes).
- [ ] Migration plan: new migrations listed, inverses verified
  (`migration_rollback_drill.sh` green for each).
- [ ] `tests/run_all.sh full` green on the release commit (all 20 gates).
- [ ] Coverage floors hold (gateway 80/70, Tier-1 70, no stale backlog).

## Deploy

- [ ] Canary: one instance first, 15 min bake, error rate vs baseline.
- [ ] Full rollout; watch `/metrics` (5xx, pool saturation, mailer fails).

## Verify (post-deploy)

- [ ] `/ready` 200 on all instances.
- [ ] One canary transfer + reconcile (`SUCCESS|RECONCILED`).
- [ ] Outbox draining (no growing `PENDING` tail).
- [ ] `scripts/release_check.sh --post-deploy` green.

## Rollback

- [ ] Criteria met? See `docs/runbooks/rollback.md` (MTTR over pride).
- [ ] Rollback PR linked in the incident; ledger reconciled after.
