# Data Model & Ownership (PR-062)

## Ownership rule

Every table added after the legacy baseline (`manifest/table_ownership.json`,
1529 grandfathered tables) must be registered before merge with:

- `owner`: the accountable area (identity, risk, market, corporate, infra…),
  not a person;
- `status`: ACTIVE / DEPRECATED;
- `tier1Links`: domain links (may be empty, never omitted);
- `audited`: where the audit trail lives (sibling table or in-row story).

The gate (`scripts/check_schema_ownership.mjs`, wired in `run_all.sh`)
fails new unregistered tables, generic financial names (`budget_amount(s)`,
`misc_data`, … — justify or rename), and stale registry entries.

## Naming

- `snake_case`, domain-prefixed (`fx_`, `screening_`, …). No generic money
  buckets without a justification note in the registry.
- Audit tables: `<base>_audit` for write paths with legal weight; in-row
  audit (actor + timestamp + reason columns) where the row IS the trail
  (reviews, consents, OTP challenges).

## Why not retrofit legacy

893+ legacy tables have no domain trace. Retrofitting ownership for all of
them is a project of its own (Phase 5 follow-up at most); the ratchet holds
the line for everything new starting now.

## Artifact policy (PR-065)

- `database/schema_full.sql` stays committed (review trail for a ledger
  schema beats a 1.4 MB saving; no per-domain split).
- CI publishes its sha256 (`schema-hash` artifact, 7 days) and runs
  `check_schema_drift.sh` (fresh rebuild from `schema.sql` + migrations must
  byte-match the committed snapshot).
- Never commit dumps/backups (`backups/`, `artifacts/`, `coverage/` are
  git-ignored); customer data never lands in the repo.
- Migration squash (657 → <150) is explicitly deferred: high-risk, solo-PR
  only, preconditions unmet (see plan PR-063).

## Baseline v2 lifecycle (PR-010)

`database/schema_v2.sql` is the post-Wave-C full snapshot (byte-identical
body to `schema_full.sql`; both are verified against a fresh build by
`check_schema_drift.sh`). Fresh installs apply it once instead of
replaying 677 migrations; existing databases keep their history.

- `database/migrate.sh --baseline`: fresh DBs apply the snapshot, record
  every current migration as covered-by-baseline (with its hash) plus a
  `baseline_v2` marker row; existing DBs must first pass the same
  membership + checksum rules as `--check` (partial DBs fail with a
  restore/finish message), then the marker is recorded. Afterwards the
  normal apply loop runs, so post-baseline migrations apply uniformly.
- `schema_v2.sql` is immutable once recorded: its sha256 rides the marker
  row, and `--check` fails a baselined database whose snapshot file was
  edited (`baseline_v2` mismatch — restore the file or re-baseline
  deliberately). PR-011 archives the covered migrations; it must not
  change this file's bytes.
- Covered by `tests/db/migration_baseline_db_tests.sh` (16 assertions):
  fresh install (snapshot + recording + table/routine counts + `--check` +
  second-run no-op), partial-upgrade refusal then heal-with-no-data-loss,
  baseline tamper detection + restore, and committed body equality.

## Migration archive (PR-011)

Pre-baseline migrations (0001–0686, 677 files) live in
`database/migrations/archive/`; `database/migrations/` holds only new,
post-baseline work. `migrate.sh` semantics:

- Fresh installs baseline first (snapshot + full recording), so the main
  loop only ever sees post-baseline files.
- `--only` / `--up-to` refuse archived versions (exit 2, names the
  baseline); restore from archive deliberately instead.
- New files must sort above the archived cutoff, else the run fails
  before applying anything (naming guard, not a silent reorder).
- `--check` verifies recorded hashes in both directories; the rollback
  drill skips when fewer than two active migrations exist.
- Restore path: files are never deleted, only relocated (`git mv`
  preserves history). To re-apply an archived migration, move it back
  to `database/migrations/` deliberately — never edit it in place.
- Covered by `tests/db/migration_archive_db_tests.sh` (12 assertions).
