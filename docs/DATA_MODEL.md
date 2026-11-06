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
