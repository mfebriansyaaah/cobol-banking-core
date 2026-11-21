# Module Authoring Guide

> **Linkage-only policy (ADR-0014, 2026-11-20):** the module generator has
> been removed. New modules are hand-written
> with domain-specific tables and domain lifecycle actions, register a real
> business table or core `CALL`, and need **L2+ linkage** plus a DB/integration
> test. Template clones are forbidden; `scripts/check_clone_budget.mjs` must
> stay at zero entries.
>
> Domains converted from the old clone template (history): Collateral, Trade
> Finance LC/BG, Merchant Acquiring, Tax Withholding, Chargeback, Payroll,
> Fixed Asset, Loyalty.
>
> Migration ranges (do not reuse, do not alter applied versions):
> Collateral 0648–0651, Trade Finance 0652–0657, Merchant 0658–0662,
> Tax 0663–0666, Chargeback 0667–0671, Payroll 0672–0675,
> Fixed Asset 0676–0679, Loyalty 0680–0683.

New SQL-backed COBOL modules must be hand-written with domain-specific
tables and actions. Do not clone `cost_center_core.cob`; clones fail
`scripts/check_clone_budget.mjs`. New modules need L2+ linkage (a proven core
business link).

## Generate a module

The module generator has been removed (ADR-0014). New modules are authored
directly with domain-specific tables and lifecycle actions; do not copy a
template body.

## Domain action shape

There is no mandatory 9-action template. Each module exposes the lifecycle its
domain actually needs (for example `OPEN`/`SETTLE`/`CANCEL`,
`SCHEDULE`/`COMPLETE`/`ESCALATE`, or `RULE_CREATE`/`CALC`/`POST`/`REVERSE`).
Generic `CREATE`/`CALC`/`DELETE` are not a contract and were removed from the
de-cloned modules. Regardless of shape:

- every write path is transactional and guarded;
- audit rows go to `<table>_audit` with actor, action, and old/new values
  where the domain needs them;
- read paths provide `LIST`/`GET` with `LIMIT`/`OFFSET`;
- money paths link to `gl_journal`/`ledger` rows instead of only storing a
  free-text reference.

## Rules

- All SQL must use `SQL_PREPARE_EXEC*` with `?` placeholders (no `SET_QUERY` + `SQL_EXECUTE`).
  Enforced by `scripts/test/prepared_auth.test.mjs` for the auth modules;
  no `INTO WS-QUERY` builders may remain there.
- Every write path wraps in `SQL_BEGIN` / `SQL_COMMIT` / `SQL_ROLLBACK`.
- Audit rows go to `<table>_audit`.
- Admin-only actions call `ALLOW-ADMIN` / `ALLOW-SUPER-ADMIN`.
- Shared boilerplate lives in `cobol/copy/` (`common_auth.cpy` provides
  `ALLOW-ADMIN` for all 4+/6-param modules; `user_core` keeps its own
  4-param variant; `common_validate_all.cpy` / `common_validate_semi.cpy`
  provide the two WS-TRIM-IN 6-param `VALIDATE-ALL`/`VALIDATE-INPUT` shapes).
  Inline exceptions stay inline with a documented reason: auth×5 (NL/CR
  charset), gl/import (action-dependent branches), ref/user (WS-CHECK
  shapes), wallet×5 (early-exit flow; wallet_core itself moved to the
  shared `wallet_entry.cpy` in PR-07) — see `scripts/test/copybook_*.test.mjs`
  for the enforced lists. Known remaining clones (DRY wave, tracked in
  `tests/duplication_baseline.txt` via `check_duplication.mjs`): TRIM-ALL in
  gl/ref only (DRY-01 converted the 22 generated clones to `common_trim.cpy`
  / `common_result.cpy`; DRY-02 moved the 5 wallet clones into the shared
  `wallet_entry.cpy`; DRY-03 moved the 6 auth entries into the shared
  `auth_entry.cpy`), TRIM-RESULT-LEN fully shared (DRY-01/DRY-03, 0 inline),
  VALIDATE-ALL / VALIDATE-INPUT in 5 modules (gl, import×2, ref, user),
  wallet audit in 6 modules and wallet caps in 5 (both shared in DRY-02),
  auth outbox shared by 3 modules in DRY-03 — each with a shrinking
  exception set in its pin test.
  A shared paragraph must be byte-identical to the copies it replaces except for caller-set variables: the caller sets
  `WS-DENIED-TARGET` before `PERFORM ALLOW-ADMIN`, and the copybook
  delegates to the host module's own `AUDIT-DENIED`. One file per
  declaration footprint: cobc validates every paragraph of an included
  copybook, so a paragraph must not reference WS vars its hosts lack
  (that broke the build once — `F-SEMI` in the shared file).
  Every new shared paragraph needs a pin test under `scripts/test/`
  (no inline regrowth, COPY present, caller invariant holds) and a
  `tests/copybook_baseline.txt` update via `check_copybooks.mjs --write`.
- Shared SQL lookups live in `cobol/copy/common_sql.cpy` (`LOOKUP-USER-ROLE`,
  `LOOKUP-USER-ID`, `LAST-INSERT-ID`, `LOOKUP-CURRENCY`: caller stages
  `WS-BIND-1` where needed, result lands in `WS-RESULT`; plus 3-bind
  `RECORD-AUTHZ-DENIED` with caller-staged 1..3).
  One file per declaration footprint applies here too: shared paragraphs
  pass at most 5 binds because 4-param modules declare no `WS-BIND-6`
  (the bridge binds exactly `nparams`, so extras are never read).
- Splitting a module: internal CALL, owner keeps dispatch + the single
  transaction, callee is transaction-free and never calls back
  ([ADR-0010](adr/0010-module-split-call-contract.md)). Pick the narrowest
  shape that fits the 8-slot LINKAGE — resolve-split, JOIN, or passthrough —
  and use `ERROR|<CODE>|<CLEANUP>` out-protocol conventions; see
  [ADR-0009](adr/0009-extraction-playbook.md). Idempotency follows the
  claim/replay/takeover protocol ([ADR-0008](adr/0008-idempotency-protocol.md));
  do not invent a sixth variant — PR-14 generalizes the table, not the semantics.
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
- Do not generate new template clones: a module shaped like
  `cost_center_core.cob` (canonical 9-action shape, ≥0.90 structural
  similarity, or exactly `TEMPLATE_LINES` lines — see
  `scripts/lib/clone_template.mjs`) with L0/L1 linkage fails
  `scripts/check_clone_budget.mjs`. New modules need L2+ linkage
  (a proven core business link — see [module linkage](MODULE_LINKAGE.md))
  or `UTILITY`/`INFRA` status. `tests/clone_baseline.txt` is now empty and
  must stay empty.

## Contract-first routes (WP-13)

`middleware/spec/routes.yaml` is the single source of truth. Never hand-edit
`middleware/src/routes/*.js`, `contracts/actions.yaml`, or `docs/openapi.yaml`;
regenerate them and review the diff.

- Adding a route with a derived field: when the gateway must compute a pipe
  slot server-side from raw client input (NIK → nikHash, name/dob/consent →
  queryHash, phone → phoneHash, imageRef → verdict), declare the raw inputs in
  `derivedFields` on the spec line, e.g.
  `derivedFields: [nik:NIK]`. The raw names must never appear in `fields`
  (the 6-slot COBOL pipe); the adapter in `middleware/adapters/signals.js`
  (via `DERIVATIONS`) produces the pipe slots, and
  `scripts/check_derivation_fields.mjs` fails the build if the two drift or a
  raw name leaks into the pipe. `RISK_NOTE` is the deliberate exception: its
  derivation needs only `email` (already a pipe field) plus the socket IP, so
  it declares no `derivedFields`.
- Adding a response mapper: parse multi-row COBOL fields only with
  `splitRows()` + `assertFieldCount()` from `middleware/src/responseMappers.js`
  (exact shape for allowlisted rows; `min` + rest-join only for free-text tails
  like statement descriptions). A short row throws → 500 via the error
  middleware, never a misaligned object. Cover the mapper in
  `middleware/test/response-mappers.test.js`.
- Regenerate after any spec change, in this order, reviewing each diff:
  `node scripts/build_routes.mjs --write`,
  `node scripts/build_contract.mjs --write`,
  `node scripts/generate_openapi.mjs --write`.
  Then `node scripts/check_contract.mjs` and `node scripts/check_openapi.mjs`
  must both print OK.
- Running the contract tests: `npm --prefix middleware run test:unit` runs
  `middleware/test/route-contract.test.js` (every route once against a stub
  COBOL binary: no 500 on well-formed output, raw derived inputs absent from
  the captured pipe). `npm run test:scripts` runs
  `scripts/test/derived_fields.test.mjs` (spec → routes → registry →
  OpenAPI round-trip, derived never in pipe).
