# Release checklist (evidence template)

Copy for each release; attach the artifacts to the release record.
Owner approver names and maintenance window are Gate 0 decisions.

- [ ] Revision: `git rev-parse HEAD` → ______
- [ ] `./ci.sh` ALL GREEN at this revision (paste tail). The lab-only `./scripts/ci-7d.sh` is not a production gate.
- [ ] COBOL floor: `./scripts/loc_report.sh --check-floor` reports at least 60.000 net COBOL lines and the curated share has not regressed.
- [ ] Generated code: no new `@generated` module enters production scope; the reference-data consolidation plan is current (`docs/PRODUCTION_GRADE_PLAN.md`).
- [ ] (Iteration only) `./ci-fast.sh` green on each pushed commit; it does not replace the full run above (`docs/adr/0076-tiered-ci.md`).
- [ ] Nightly coverage gate green for the current revision (or a docs-only difference) within the release window; paste the `scripts/nightly.sh` log tail (`docs/adr/0078-coverage-cadence.md`).
- [ ] `npm audit --omit=dev --audit-level=high`: clean / exception #__
- [ ] Migrations reviewed (backward compat, triggers, seeds):
      `ls database/migrations/` new since last release → ______
- [ ] `schema_migrations` matches the migration files on a fresh apply
- [ ] Fresh backup taken: manifest file → ______
- [ ] Runbooks still accurate for this release (changes noted?)
- [ ] Rollback plan: previous revision ______ + backup manifest above
- [ ] Security evidence: SAST/DAST, dependency scan, SBOM, secret scan, and open critical/high findings → ______
- [ ] Reliability evidence: SLO/RPO/RTO review and the latest backup/restore or DR drill → ______
- [ ] Data governance: new tables/columns classified, retained, and lineage reviewed → ______
- [ ] Approvals: compliance ______ finance ______ security ______ ops ______
