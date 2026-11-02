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

- `dashboard_core`, `eod_jobs_core`: read-only/aggregation, no `SQL_BEGIN` transaction.
- `auth_password_core`, `hashlen_core`: no admin guard / no bind slots (utility).
- `user_core`: 5 bind slots (sufficient for its queries).

## Standardization rules

- All SQL must use `SQL_PREPARE_EXEC*` with `?` placeholders.
- Every write path wraps in `SQL_BEGIN` / `SQL_COMMIT` / `SQL_ROLLBACK`.
- Admin-only actions call `ALLOW-ADMIN` or `ALLOW-SUPER-ADMIN`.
- Keep `WS-PREP-SQL` ≤ 1024 chars and params ≤ 6 (7 for EXEC7).
- Warning baseline must be 0 for Tier 1; Tier 2 may start with a recorded baseline.
