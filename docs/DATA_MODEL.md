# Data Model & Ownership (PR-062)

## Ownership rule

Every table added after the legacy baseline (`manifest/table_ownership.json`,
1539 grandfathered tables) must be registered before merge with:

- `owner`: the accountable area (identity, risk, market, corporate, infra…),
  not a person;
- `status`: ACTIVE / DEPRECATED;
- `coreLinks`: domain links (may be empty, never omitted);
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

Legacy tables (see `manifest/table_ownership.json`) have no domain trace. Retrofitting ownership for all of
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

## Baseline v2 lifecycle (experimental, not canonical)

`database/schema_v2.sql.gz` is generated from `database/schema_full.sql` and is
kept compressed for drift comparison only. It is **not** the fresh-install path
used by README or CI in this release.

- Canonical fresh install: `database/schema.sql` + `database/migrate.sh`.
- Experimental fast install: `database/migrate.sh --baseline`; not adopted by
  CI, drills, or onboarding until a separate migration PR updates every caller.
- `schema_v2.sql.gz` remains immutable while the experimental path is tested.

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
