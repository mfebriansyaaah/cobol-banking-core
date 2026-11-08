# Module Classification

Modules fall into three tiers. The tier decides how strictly the 9-action
contract and the warning ratchet apply.

## Tier 1 — Core / business-critical

Hand-written or heavily reviewed modules that own domain rules, money movement,
identity, or authorization. They are expected to reach 0 warnings.

- `auth_core`, `auth_password_core` (utility delegate), `user_core`, `wallet_core`
- `loan_core`, `loan_schedule_core`, `deposit_core`, `card_core`, `collection_core`
- `payment_clearing_core`, `treasury_liquidity_core`, `gl_core`, `fee_core`

## Tier 2 — Generated domain modules

Produced from `cobol/src/cost_center_core.cob` via `scripts/generate_module.py`.
They follow the standard 9-action contract (CREATE, LIST, GET, CALC/UPDATE,
DELETE/CLOSE, SUMMARY, AUDIT, VALIDATE, plus a domain action) and use
`SQL_PREPARE_EXEC*` with `?` placeholders. New modules belong here.

## Tier 3 — Utilities

- `hashlen_core` (binary-level helper)
- `ref_engine`, `ref_ext_core` (reference data)

## Intentional exceptions

- `dashboard_core`: read-only/aggregation, no `SQL_BEGIN` transaction.
- `eod_jobs_core`: orchestrator, not a transaction owner (ADR-0006). START/FINISH
  run autocommit; money work happens in the called modules' own transactions.
  No orphan `COMMIT`/`ROLLBACK` without `BEGIN`.
- `auth_password_core`, `hashlen_core`: no admin guard / no bind slots (utility).
- `user_core`: 5 bind slots (sufficient for its queries).

## Standardization rules

- All SQL must use `SQL_PREPARE_EXEC*` with `?` placeholders.
- Every write path wraps in `SQL_BEGIN` / `SQL_COMMIT` / `SQL_ROLLBACK`.
- Admin-only actions call `ALLOW-ADMIN` or `ALLOW-SUPER-ADMIN`.
- Keep `WS-PREP-SQL` ≤ 1024 chars and params ≤ 6 (7 for EXEC7).
- Warning baseline must be 0 for Tier 1; Tier 2 may start with a recorded baseline.

## Tier-1 linkage (L0–L3)

A module's tier says how strictly it is reviewed; its **linkage level** says
whether it is actually tied to the Tier-1 core. Linkage is measured from
evidence, not from size or template similarity, by
`scripts/build_tier1_graph.mjs` (definition: `manifest/tier1.json`, output:
`manifest/tier1_links.json`, human-readable: `docs/TIER1_LINKAGE.md`).

| Level | Meaning |
| --- | --- |
| L3 | Tier-1 core, or money-table touch with depth plus a proving test |
| L2 | Business-table reference, Tier-1 CALL, or money-action literal, plus a test |
| L1 | Reference-only (`users`/`currencies`/`ref_*`, incl. the `ALLOW-ADMIN` role lookup) or linked code with no test |
| L0 | Isolated: own generic tables only, or no table references at all |
| UTILITY | Tier-3 helper (`hashlen_core`, `ref_engine`, `ref_ext_core`); never a retire candidate |

Rules:

- The `ALLOW-ADMIN` role lookup (`SELECT role FROM users WHERE email = ?`)
  and audit actor fields are **not** linkage.
- New modules/routes need L2+ linkage (or `UTILITY`/`INFRA` status); L0/L1 is rejected.
- L0/L1 is refactored never, retired eventually (`tests/tier1_links_baseline.txt`
  is the ratchet; `scripts/check_tier1_links.mjs` enforces it in `run_all.sh fast`).
