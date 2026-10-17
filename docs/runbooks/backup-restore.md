# Backup and restore

Status: tested mechanism. Schedule, retention, storage location, and
RPO/RTO are owner decisions (Gate 0); until approved, take a backup
before every release and verify it with the suite.

## Take a backup

```sh
DB_NAME=cobol_db DB_USER=cobol_user DB_PASS=... ./scripts/backup.sh /srv/backups
```

Produces `cobol-<db>-<utc>.sql` plus a `.manifest` (git revision,
per-table row counts, live checksums), both chmod 600. The dump
contains password hashes and MFA secrets: move it to owner-approved
encrypted storage immediately; never commit it, email it, or leave it
on shared disk.

## Restore (tested path)

```sh
DB_USER=... DB_PASS=... ./scripts/restore.sh /srv/backups/cobol-<db>-<utc>.sql [target-db]
```

The script replays the dump, then verifies per-table counts and
checksums against the manifest, re-runs the migration check, and
smoke-tests the bridge. Any mismatch fails loudly — a failed restore
must be treated as an incident (see `incident-response.md`), not
retried blindly: the target may be partially restored. Re-run the
restore from the same file once the cause is understood; it is
idempotent for a good file.

## Partial-failure notes

- `mysqldump --single-transaction` gives a consistent snapshot without
  locking writers. A restore replays table by table; if it aborts
  mid-file, earlier tables are at backup state and later ones are
  untouched — always check the verification output, never assume.
- Restoring an older backup discards newer rows by design. Confirm the
  manifest timestamp before restoring anywhere shared.
- `tests/test_backup_restore.sh` exercises this exact path in CI with
  a canary row that must disappear after the round-trip.

## Retention (owner-TBD)

Keep manifests with the release record (see `../release-checklist.md`).
Purge schedules, legal holds, and off-site copies require owner
approval; `audit_trail_archive` and `pending_transactions_archive`
are the current long-term stores for those streams.
