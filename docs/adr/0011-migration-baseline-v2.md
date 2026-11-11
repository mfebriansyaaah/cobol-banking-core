# ADR 0011: Migration baseline v2

## Status

Proposed. Approval is recorded below; merge of the PR-00B branch by the
owner is the approval, and flips this to Accepted.

## Context

Every fresh install applies `database/schema.sql` (baseline-0037, 479
tables) and then 677 migration files one by one (`database/migrate.sh`
records each version in `schema_migrations` only on success). The chain is
correct but expensive: hundreds of sequential `mysql` invocations, 677 files
to review, and a growing `migrate.sh --check` surface. Steady-state `--check`
on an applied database already costs ~4s (measured 2026-11-12); a full fresh
install is an order of magnitude slower (exact timing is measured in the
PR-10 dry run, which has a DDL-capable isolated database).

The integrity machinery must survive the squash:

- `schema_migrations.checksum` (added by migration 0666) makes applied files
  tamper-evident; `--check` fails on hash mismatch or missing hashes.
- `database/schema_full.sql` is the canonical snapshot: built by
  `scripts/generate_schema_snapshot.sh` (throwaway DB, `mysqldump --no-data`
  with normalization) and byte-compared by `scripts/check_schema_drift.sh`.
- The rollback drill replays with `migrate.sh --up-to` from snapshots.

A baseline that breaks any of these trades install speed for silent drift,
which is worse than slowness. So the baseline is a snapshot plus a marker,
not a rewrite.

## Decision

**Snapshot baseline with a marker row, archive after one release window.**

1. `database/schema_v2.sql` is generated from the current
   `database/schema_full.sql` (same normalization, same generator family).
   It becomes the fresh-install baseline. It is generated, never hand-edited.
2. A `baseline_v2` marker row in `schema_migrations` records the cutover:
   - Fresh install: apply `schema_v2.sql`, insert `baseline_v2` (with the
     file's SHA-256 in `checksum`), then apply only post-baseline migrations.
   - Existing database: `migrate.sh --baseline` verifies every pre-baseline
     migration is applied with matching checksums, inserts `baseline_v2`,
     then continues with post-baseline migrations. A partial database fails
     with a named list and an instruction to restore, never with a partial
     marker.
3. Pre-baseline migration files move to `database/migrations/archive/` in
   PR-11 (one release window after the baseline lands). `migrate.sh` never
   scans `archive/` for fresh installs; `--check` verifies recorded
   checksums for archived versions without requiring their files.
4. `check_schema_drift.sh` rebuilds from `schema_v2.sql` plus active
   migrations and byte-matches the regenerated snapshot. The snapshot stays
   committed.
5. No table is renamed or dropped by the baseline itself: it is a snapshot
   of exactly what the chain produces, so old binaries stay compatible
   during the release window.

## Upgrade matrix

| Scenario | Baseline v2 | New migrations | Expectation |
| --- | --- | --- | --- |
| Fresh install | apply `schema_v2.sql` + marker | apply | schema byte-identical to `schema_full.sql` |
| Existing DB, complete | verify all + marker | apply | no data loss; old versions stay recorded |
| Existing DB, partial | refuse, list missing | hold | fail with names + restore instruction |
| Old binary + new DB | n/a | n/a | compatible inside the release window (no renames/drops) |
| Rollback | restore snapshot | — | backup/restore drill green, `migrate.sh --check` clean |

## Dry-run plan (executed in PR-10)

The dry run needs a DDL-capable isolated database
(`docker-compose.test.yml`, port 3307, `scripts/dev/setup-test-db.sh`);
the least-privilege app credentials cannot create databases, so the dry run
cannot happen on a developer database. Steps, in order:

1. Snapshot the isolated database before touching anything.
2. Fresh install: apply `schema_v2.sql`, record the marker, apply
   post-baseline migrations. Expect: `migrate.sh --check` clean.
3. Rebuild the snapshot with `generate_schema_snapshot.sh` and expect
   `check_schema_drift.sh` byte-identical.
4. Existing-complete upgrade: build the old chain (`schema.sql` + all
   migrations) on a second database, run `migrate.sh --baseline`, expect
   the marker plus identical dumps before/after (data kept).
5. Existing-partial upgrade: stop the old chain halfway, run
   `migrate.sh --baseline`, expect failure naming the missing versions and
   no marker row.
6. Time steps 2–4 and record fresh-install before/after in the PR-10 body.
7. Run `scripts/ci/backup_restore_drill.sh` and
   `scripts/ci/migration_rollback_drill.sh` against the result.

Read-only evidence collected for this design (2026-11-12, dev database):

- `./database/migrate.sh --check` → `all migrations applied` in ~4s.
- App credentials have no DDL rights (CREATE DATABASE refused) — confirms
  the dry run must use the isolated DDL-capable database, as planned.
- `check_schema_drift.sh` green on PR #641 — the snapshot generator is
  reproducible, so a snapshot-derived baseline is trustworthy input.

## Rollback plan

- Before: backup/restore drill green; snapshot retained through the release
  window.
- If the baseline build fails: delete `schema_v2.sql`, revert the PR, keep
  the old chain. Existing databases are untouched (the marker is only
  written after full verification).
- If a database already recorded the marker: restore the pre-cutover
  snapshot, run `migrate.sh --check` on the old chain.
- Archive (PR-11) is move, not delete: restoring `archive/*.sql` plus a
  revert returns the tree to the pre-baseline state.

## Retention and compatibility

- Pre-baseline files stay in `archive/` for at least one release window;
  permanent deletion is a separate decision with its own PR.
- `migrate.sh --check` on an old database must keep passing after the
  archive move (recorded checksums are verified, missing files are not
  required).
- No rename/drop in the baseline: old binaries read the new schema during
  the window. The first rename/drop after the baseline is a normal
  post-baseline migration, reviewed like any other.
