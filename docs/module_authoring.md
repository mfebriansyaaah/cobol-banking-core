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
- Shared boilerplate lives in `cobol/copy/` (`common_auth.cpy` provides
  `ALLOW-ADMIN` for all 4+/6-param modules; `user_core` keeps its own
  4-param variant; `common_validate_all.cpy` / `common_validate_semi.cpy`
  provide the two WS-TRIM-IN 6-param `VALIDATE-ALL`/`VALIDATE-INPUT` shapes).
  Inline exceptions stay inline with a documented reason: auth×5 (NL/CR
  charset), gl/import (action-dependent branches), ref/user (WS-CHECK
  shapes), wallet×6 (early-exit flow) — see `scripts/test/copybook_*.test.mjs`
  for the enforced lists.
  A shared paragraph must be byte-identical to the copies it replaces except for caller-set variables: the caller sets
  `WS-DENIED-TARGET` before `PERFORM ALLOW-ADMIN`, and the copybook
  delegates to the host module's own `AUDIT-DENIED`. One file per
  declaration footprint: cobc validates every paragraph of an included
  copybook, so a paragraph must not reference WS vars its hosts lack
  (that broke the build once — `F-SEMI` in the shared file).
  Every new shared paragraph needs a pin test under `scripts/test/`
  (no inline regrowth, COPY present, caller invariant holds) and a
  `tests/copybook_baseline.txt` update via `check_copybooks.mjs --write`.
- Keep `WS-PREP-SQL` ≤ 1024 chars (bridge buffer limit) and params ≤ 6 (7 for EXEC7).
- New modules are picked up by `cobol/Makefile` automatically (wildcard); no
  `build.sh` change needed. Regenerate the manifest, and add tests + warning
  baseline entry.
- Every new gateway action must be invoked by at least one shell-level test
  (`run_cobol` in a DB suite or `@@ACTION` in a table case), or recorded in
  `tests/action_test_coverage_baseline.txt` with a reason — see the action
  coverage ratchet in [TESTING.md](TESTING.md).
- Route fields must stay in the exact COBOL `LS-PARAM` order (6 positional
  slots; `deposit_core` takes 7 with the idempotency key in slot 7,
  `user_core` takes 4 — slots past a program's count must be `BLANK`
  padding, enforced by `scripts/check_program_signatures.mjs`). After adding or changing a route, run
  `node scripts/generate_field_order.mjs --write .`, review the snapshot
  diff in `tests/contracts/route_field_order.json`, and explain it in the
  PR — see the cross-layer contract section in [TESTING.md](TESTING.md).
- Do not generate new template clones: a new module shaped like
  `cost_center_core.cob` (canonical 9-action contract, ≥0.90 structural
  similarity, or exactly 669 lines) with L0/L1 linkage fails
  `scripts/check_clone_budget.mjs`. New modules need L2+ linkage
  (a proven Tier-1 business link — see [module classification](module_classification.md))
  or `UTILITY`/`INFRA` status. The existing clones are frozen in
  `tests/clone_baseline.txt`, which must only shrink.
