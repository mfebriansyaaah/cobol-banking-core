# Rollback (PR-070)

Deploys are merge commits on `main`; rollback is reverse motion, not repair.

## Gateway / COBOL (stateless)

1. `git revert -m 1 <merge-commit>` (or redeploy the previous image/tag).
2. Restart gateway (pool workers pick up the old binary on spawn).
3. Verify: `/ready` 200, `tests/run_all.sh fast`, one canary transfer.

## Database (stateful — never `git revert` alone)

1. Migrations are forward-only; every migration must have a tested inverse.
   Rollback = restore from backup OR apply the inverse migration — decide by
   data loss window, document the choice in the incident.
2. `migration_rollback_drill.sh` proves inverses monthly; a migration
   without a drill entry does not ship.
3. Outbox rows survive rollback (they are the delivery guarantee); replays
   are idempotent by `txn_ref`/`idempotency-key`.

## Rules

- Roll back first, root-cause after (MTTR beats pride).
- A rollback that touches money rows needs a second pair of eyes + a
  post-deploy ledger reconcile (`RECONCILE` → `SUCCESS|RECONCILED`).
