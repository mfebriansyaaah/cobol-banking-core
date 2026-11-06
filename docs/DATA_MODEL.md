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
