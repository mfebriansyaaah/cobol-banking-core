# Deploy and rollback

Status: procedure. Approvers and maintenance windows are owner decisions
(Gate 0); the steps below are the same for every release.

## Release prerequisites (see `../release-checklist.md`)

- `main` is green (`./ci.sh` ALL GREEN) at the release revision.
- A fresh backup exists and its manifest is attached to the release
  record (`./scripts/backup.sh`).
- Migrations in the release were reviewed (see below).

## Deploy

1. Announce the window; drain writers (stop gateway pool / service).
2. `git pull` the release revision; run `./database/migrate.sh`
   (idempotent; each migration applies once, recorded in
   `schema_migrations`).
3. `./build.sh`, then `./ci.sh`. Any red step stops the deploy.
4. Restart the gateway and outbox worker; confirm `/ready` and a
   `RUN_RECONCILIATION` with no new findings.

## Migration review (change control)

- Every `database/migrations/*.sql` is reviewed for: backward
  compatibility with the running bridge (no dropped column in use, no
  narrowed type), trigger interplay (append-only tables keep their
  guards), and seed determinism.
- Destructive statements (`DROP`, data rewrites) require an explicit
  justification comment in the migration file.
- If a migration fails, `migrate.sh` stops before recording it: fix
  forward with a new migration. Never edit an applied migration on a
  shared database; schema and code ship together at one revision.

## Rollback

- Code: revert to the previous release revision (`git revert`, never
  history rewrite) and redeploy.
- Data: if the release wrote bad data, restore the pre-release backup
  (`backup-restore.md`). Code rollback alone never repairs data.
- Partial deployment (some hosts old, some new): the bridge protocol
  is backward compatible within a release line; drain, converge all
  hosts to one revision, re-run `./ci.sh`, then re-enable writers.

## Release record

Attach to the release: revision, `./ci.sh` tail, migration list from
`schema_migrations`, backup manifest, approver names, and the completed
`../release-checklist.md`.
