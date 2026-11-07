# Disaster Recovery (PR-070)

## Backups

- Nightly `mysqldump` (see `scripts/backup.sh`), retained per policy,
  verified by `backup_restore_drill.sh` (restore to a scratch DB + checksum
  the migration ledger + spot-check balances).
- Vault objects (MinIO): versioned bucket; production uses distributed MinIO
  with replication (dev single-node is not DR).

## Restore

1. Provision a clean host; install pinned MariaDB (version in compose).
2. Restore the latest verified backup; run `./database/migrate.sh --check`
   (ledger must match committed migrations exactly).
3. Point the gateway at the restored DB; `/ready` → canary transfer →
   reconcile.
4. RTO target: < 4 h. RPO target: < 24 h (nightly window). Measure both in
   every drill; file gaps as issues, not footnotes.

## Secrets & certs

- Secrets live in the secret manager, not backups. Rotation procedure:
  `docs/runbooks/secret-rotation.md`.
- TLS certs: provider-managed with 30-day expiry alerts; rotation is
  reload-only (no restarts).
