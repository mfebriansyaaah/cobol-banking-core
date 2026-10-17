# Release checklist (evidence template)

Copy for each release; attach the artifacts to the release record.
Owner approver names and maintenance window are Gate 0 decisions.

- [ ] Revision: `git rev-parse HEAD` → ______
- [ ] `./ci.sh` ALL GREEN at this revision (paste tail, 64 steps)
- [ ] `npm audit --omit=dev --audit-level=high`: clean / exception #__
- [ ] Migrations reviewed (backward compat, triggers, seeds):
      `ls database/migrations/` new since last release → ______
- [ ] `schema_migrations` matches the migration files on a fresh apply
- [ ] Fresh backup taken: manifest file → ______
- [ ] Runbooks still accurate for this release (changes noted?)
- [ ] Rollback plan: previous revision ______ + backup manifest above
- [ ] Approvals: compliance ______ finance ______ security ______ ops ______
