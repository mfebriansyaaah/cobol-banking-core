# Module Authoring Guide

New SQL-backed COBOL modules should be generated from the canonical template
rather than copied by hand, so the 9-action contract and boilerplate stay
consistent.

## Generate a module

```bash
scripts/generate_module.py <domain> <PREFIX> <table> <ref_field> <name_field> <type_field>
# example:
scripts/generate_module.py vendor VND_ vendor vendor_ref vendor_name vendor_type
```

The generator copies `cobol/src/cost_center_core.cob` (the canonical template)
and applies the domain-specific renames.

Shared plumbing (`TRIM-VALUE`, `TRIM-ALL`, `TRIM-RESULT-LEN`,
`VALIDATE-INPUT`, `VALIDATE-ALL`) lives in
`cobol/copy/common_plumbing.cpy` and is pulled into every generated module
with a single `COPY "common_plumbing.cpy".` line — do not inline these
paragraphs in new modules. Because the generator copies the template, new
modules inherit the `COPY` automatically. Hand-written Tier-1 modules keep
their own variants and are excluded from the copybook.

## Standard 9-action contract

Every domain module exposes these actions (prefix + action):

1. `<PFX>_CREATE` — insert a new row in a transaction, enqueue outbox if needed.
2. `<PFX>_LIST` — paginated list (LIMIT/OFFSET via `SQL_PREPARE_EXEC_ROWS`).
3. `<PFX>_GET` — single row by id/ref.
4. `<PFX>_CALC` / domain action — core business operation.
5. `<PFX>_UPDATE` — guarded update with version check.
6. `<PFX>_DELETE` / `CLOSE` — soft delete or close.
7. `<PFX>_SUMMARY` — aggregate counts/totals.
8. `<PFX>_AUDIT` — paged audit trail.
9. `<PFX>_VALIDATE` — input validation without writes.

## Rules
- All SQL must use `SQL_PREPARE_EXEC*` with `?` placeholders (no `SET_QUERY` + `SQL_EXECUTE`).
- Every write path wraps in `SQL_BEGIN` / `SQL_COMMIT` / `SQL_ROLLBACK`.
- Audit rows go to `<table>_audit`.
- Admin-only actions call `ALLOW-ADMIN` / `ALLOW-SUPER-ADMIN`.
- Keep `WS-PREP-SQL` ≤ 1024 chars (bridge buffer limit) and params ≤ 6 (7 for EXEC7).
- Add the module to `build.sh`, regenerate the manifest, and add tests + warning baseline entry.