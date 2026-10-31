# Module Authoring Guide

> **Freeze (2026-10-29, domain-nyata program):** do not generate new modules
> from `cost_center_core.cob` via `scripts/generate_module.py` without a domain
> design review. New modules must have domain-specific tables (no generic
> `ref/name/type/budget_amount/spent_amount`) and at least one integration
> with a core module (customer, account, loan, payment, fee, GL, KYC/AML).
> Converting domains and migration ranges are listed below; details in
> `docs/domain_overview.md`.
>
> Converting (in order): Collateral (done pilot), Trade Finance LC/BG,
> Merchant Acquiring, Tax Withholding, Chargeback, Payroll, Fixed Asset,
> Loyalty. All other Tier-2 clones are frozen.
>
> Migration ranges (do not reuse, do not alter applied versions):
> Collateral 0648–0651, Trade Finance 0652–0657, Merchant 0658–0662,
> Tax 0663–0666, Chargeback 0667–0671, Payroll 0672–0675,
> Fixed Asset 0676–0679, Loyalty 0680–0683.

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
- Route fields must stay in the exact COBOL `LS-PARAM` order (6 positional
  slots). After adding or changing a route, run
  `node scripts/generate_field_order.mjs --write .`, review the snapshot
  diff in `tests/contracts/route_field_order.json`, and explain it in the
  PR — see the cross-layer contract section in [TESTING.md](TESTING.md).