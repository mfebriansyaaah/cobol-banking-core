# Operations hardening: backup/restore, runbooks, dependency audit

Status: accepted
Date: 2026-10-17
Phase: Gate 2 — production controls (partial; Gate 3 owner items stay open).

## Context

`PRD_Enterprise.md` section 4.F requires resilience, security operations,
data lifecycle, and change control. Missing were a tested backup/restore
path, incident/runbook procedures, dependency vulnerability gating, and
release evidence — all implementable without owner decisions, unlike
SLOs/RPO/RTO, which stay blocked on Gate 0.

## Decision

- `scripts/backup.sh`: consistent `mysqldump --single-transaction`
  snapshot plus a manifest (git revision, per-table counts and live
  checksums), files chmod 600. `scripts/restore.sh`: replay plus
  verification (counts, checksums, migration check, bridge smoke);
  any mismatch fails loudly.
- `tests/test_backup_restore.sh` (15 checks): round-trips the live
  database in CI with a canary row that must disappear after restore.
- `docs/runbooks/`: incident response, alert response (signal inventory;
  thresholds stay owner-approved data, never code), backup/restore, and
  deploy/rollback (migration review rules, forward-only fixes, data
  rollback via restore).
- CI step 63: `npm audit --omit=dev --audit-level=high`; failures block
  until fixed or an exception is recorded per `docs/patch-policy.md`.
- `docs/release-checklist.md`: per-release evidence template (revision,
  CI tail, migrations, backup manifest, approver names).

## Consequences

- Backup/restore and change-control procedure are now tested evidence,
  not claims. F-P0-RESIL/F-P0-SECOPS/F-P1-CHANGE stay partial: approved
  SLOs, RPO/RTO, schedules, retention, and independent assessment still
  need owners (traceability rows updated, Gate 3 still blocked).
- Restoring an older backup discards newer rows by design; the runbook
  requires manifest confirmation before any shared restore.
