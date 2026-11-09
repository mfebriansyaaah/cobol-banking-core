# Cobol Banking Core

A banking backend where **COBOL is the authoritative business tier**. Every
balance, limit, status transition, and ledger mutation is decided and executed
in COBOL. Node/Express is only the HTTP gateway (routing, input-shape
validation, authentication), and C provides the MySQL bridge plus the low-level
crypto helpers COBOL cannot call directly.

[![CI](https://github.com/mfebriansyaaah/cobol-banking-core/actions/workflows/ci.yml/badge.svg)](https://github.com/mfebriansyaaah/cobol-banking-core/actions/workflows/ci.yml)

> **CI status (2026-11-04):** automatic triggers restored in Phase 0 branch 01
> (`push: [main]`, `pull_request`, schedules). See [docs/CI.md](docs/CI.md).
>
> **Status (2026-10-29):** COBOL modules follow the 9-action contract (see
> `docs/module_classification.md`): Tier-1 hand-reviewed core (auth, wallet,
> lending, …) plus Tier-2 generated domain modules and Tier-3 utilities.
> `tests/run_all.sh full` is green locally and in the hosted CI gate.
> Counts in this README are generated from `manifest/modules.json` and the
> source tree; see [docs/STATUS.md](docs/STATUS.md) and
> [docs/MODULE_INDEX.md](docs/MODULE_INDEX.md).

## Architecture

```text
Client
  │  HTTPS / JSON
  ▼
middleware/src/                 Node 18+ / Express 5 (transport only)
  app.js                       route table: HTTP → COBOL action
  routes/*.js                  per-domain field order + patterns
  validation.js                request shape, no business rules
  auth.js + authService.js      JWT access/refresh, MFA, step-up (session orchestration)
  invoker.js + pool.js         file mode or warm worker pool
  │  pipe protocol: ACTION|P1|P2|P3|P4|P5|P6
  ▼
cobol/bin/main_logic            GnuCOBOL, one binary
  main_logic.cob               prefix dispatch (count in docs/STATUS.md)
  *_core.cob                   business logic + transactional SQL
  │  SQL_BEGIN / SQL_PREPARE_EXEC / SQL_PREPARE_EXEC_ROWS / SQL_COMMIT
  ▼
cobol/src/sql_bridge.c          MySQL C API prepared statements
  ▼
MariaDB / MySQL — database `cobol_db`
```

Domain-adjacent policy lives outside the gateway: `middleware/services/`
(integrations, mailer) and background work in `middleware/workers/`.

Rules of the split:

- **COBOL** owns domain rules: authorization, limits, status machines,
  idempotency, currency checks, interest, fees, and every write.
- **JavaScript** owns transport: URL parsing, regex validation, JWT/MFA,
  rate limits, and mapping `SUCCESS|…` / `ERROR|CODE|…` to HTTP.
- **C** owns database connectivity (`sql_bridge.c`) and the crypto/settings
  primitives in `cobol/c_lib/`.

## Repository layout

| Path | Contents |
| --- | --- |
| `cobol/src/` | COBOL modules + `main_logic.cob` dispatcher + `sql_bridge.c` (count in `docs/STATUS.md`) |
| `cobol/copy/` | Three copybooks used only by the password/auth module |
| `cobol/c_lib/` | PBKDF2, TOTP, CSPRNG, settings helpers |
| `cobol/bin/` | Build output (`main_logic`), gitignored |
| `middleware/src/` | Express gateway (transport only): route modules, barrel, authService, and core helpers |
| `middleware/services/` | Integration services + mailer (domain-adjacent policy, outside the gateway) |
| `middleware/workers/` | Background workers (outbox dispatcher) |
| `middleware/test/` | Gateway test suite (run with `npm --prefix middleware test`) |
| `database/` | `schema.sql` baseline, migrations, seed, grants (counts in `docs/STATUS.md`) |
| `tests/` | Unified runner, table-driven COBOL cases, DB suites, harness |
| `manifest/modules.json` | Generated registry of modules, routes, and dispatch entries |
| `scripts/` | `generate_manifest.mjs`, `check_manifest.mjs` |
| `monitoring/` | Prometheus alert rules for the gateway |
| `build.sh` | Compiles the dispatcher, all COBOL modules, and the C bridge |
| `.github/workflows/ci.yml` | Hosted CI: build + warning ratchet, then full test gate |
| `ci.sh`, `ci-fast.sh` | Local CI entry points |

## Implementation status

Flagship hand-reviewed domains (Tier 1). The full generated inventory is
[docs/MODULE_INDEX.md](docs/MODULE_INDEX.md); counts are in
[docs/STATUS.md](docs/STATUS.md).

| Domain | Status | Modules |
| --- | --- | --- |
| Platform | Done | `auth_core`, `auth_password_core`, `user_core`, `wallet_core`, `ref_engine`, `ref_ext_core`, `gl_core`, `batch_core`, `report_core`, `fee_core`, `eod_core`, `statement_core`, `notification_core`, `alert_core`, `dashboard_core`, plus audit/compliance/ops modules |
| D1 Lending | Done | `loan_schedule_core` (28 actions), `loan_core` |
| D2 Deposit | Done | `deposit_core` (13 actions) |
| D3 Cards | Done | `card_core` (16 actions) |
| D4 Collections | Done | `collection_core` (15 actions) |
| D5 Payments | Done | `payment_clearing_core` (9 actions) |
| D6 Treasury / FX | Done | `treasury_liquidity_core` (9 actions) |
| D7 Compliance | Done | `kyc_periodic_core` (9 actions) |
| D8 Finance | Done | `gl_allocation_core` (9 actions) |
| D9 IT Ops | Done | `backup_drill_core` (9 actions) |
| D11 Compliance (AML) | Done | `aml_screening_core` (9 actions) |
| D12 Sanctions List | Done | `sanctions_list_core` (9 actions) |
| D13 Fraud Case | Done | `fraud_case_core` (9 actions) |
| D10 Data / Reporting | Done | `report_builder_core` (9 actions) |
| Collateral Mgmt | Done (pilot) | `collateral_core` (17 actions: register/appraise/revalue/pledge/allocate/release/repossess/dispose + CRUD/audit); legacy `collateral_mgmt`, `collateral_repossession`, `collateralized` deprecated, kept for compat |
| Trade Finance | Done (pilot) | `letter_of_credit_core` (LC lifecycle + GL link), `bank_guarantee_core` (BG lifecycle + claim); legacy `trade_finance`, `documentary_credit`, `bankers_acceptance`, `export_finance`, `import_finance`, `factoring` deprecated |
| Merchant Acquiring | Done (pilot) | `merchant_core` (onboarding + fee profile), `merchant_settlement_core` (txn/fee/settle/payout + GL link); legacy generic CREATE/CALC/UPDATE/DELETE deprecated |
| Tax Withholding | Done (pilot) | `tax_management_core` (rule engine + calc/post/reverse/report); legacy `tax_withholding`, `tax_item` deprecated |
| Chargeback | Done (pilot) | `chargeback_core` (open/assign/evidence/represent/accept/reject/arbitrate/close + hold/release/debit ledger); generic `chargeback` write paths + `dispute_management` deprecated |
| Payroll | Done (pilot) | `payroll_processing_core` (validate/approve/process/pay/close + tax rule + balance + GL/payment links); generic CREATE/CALC/UPDATE/DELETE kept for compat |
| Loyalty / Rewards | Done (pilot) | `loyalty_core` (create/activate/enroll/earn/redeem/expire/adjust + ledger/GL link); generic `loyalty_program`, `rewards_management`, `points_redemption`, `cashback` write paths deprecated |
| Fixed Asset | Done (pilot) | `fixed_asset_core` (capitalize/depreciate/revalue/dispose + GL link + audit); generic CREATE/CALC/UPDATE/DELETE kept for compat, `asset_management` deprecated |

### Status details

Current counts, module inventory, and route/test coverage are generated:

- [Repository status](docs/STATUS.md)
- [Module index](docs/MODULE_INDEX.md)
- [Coverage report and limits](docs/COVERAGE.md)
- [Governance and merge policy](docs/GOVERNANCE.md)

## Testing and CI status

This table reflects what is actually wired into the repository and CI. It is
not a maturity score.

| Area | Status | Evidence |
| --- | --- | --- |
| Table-driven COBOL cases | ✅ | `tests/cobol/cases/*.cases`, `tests/cobol/table_runner.sh` |
| DB domain suites | ✅ | `tests/db/*_db_tests.sh`, `tests/run_all.sh db` |
| Gateway tests | ✅ | `middleware/test/*.test.js`, `npm --prefix middleware test` |
| Integration tests | ✅ | `tests/integration/*.sh` (all flows, via `tests/run_all.sh full` / `integration`) |
| Fuzz tests | ✅ | `tests/fuzz/fuzz_inputs.sh` |
| SAST | ✅ | `scripts/ci/sast.sh`, `scripts/ci/sast_extra.sh` |
| Migration rollback + backup/restore drills, schema drift | ✅ | `scripts/ci/migration_rollback_drill.sh`, `scripts/ci/backup_restore_drill.sh`, `scripts/check_schema_drift.sh` |
| Performance benchmarks | ✅ | `tests/perf/bench.sh` |
| Coverage gate | ✅ | `scripts/ci/coverage.sh`, `tests/coverage_baseline.txt`; COBOL is a curated-core floor |
| Warning ratchet | ⚠️ | `scripts/check_warnings.sh`; a few non-zero entries remain |
| Mutation testing | ❌ | Not implemented; the probe harness tests gates, not mutants |
| CI build under 2 minutes | ❌ | Full build/test is intentionally heavier |

### Coverage scope

Coverage is split into a curated COBOL core and the full gateway surface. The
COBOL number is a floor over the modules listed in `scripts/ci/coverage.sh`,
not a whole-tree claim. Generated domain modules are covered by their DB
suites, table cases, and the action/suite inventory gates. See
[docs/COVERAGE.md](docs/COVERAGE.md) for the exact scope and limits.

## Measured on this checkout

<!-- BEGIN GENERATED STATS -->
| Metric | Value |
| --- | ---: |
| COBOL modules | **66** |
| COBOL source files (incl. dispatcher) | **67** |
| COBOL lines | **57,519** |
| Gateway route files | **54** |
| Gateway route definitions | **573** |
| Dispatch entries | **193** |
| Recorded migrations | **666** |
| Tables in schema.sql | **479** |
<!-- END GENERATED STATS -->

## Request contract

The gateway and the binary speak one line per request:

```text
ACTION|PARAM1|PARAM2|PARAM3|PARAM4|PARAM5|PARAM6
```

- Request line: max **500 bytes**. `ACTION`: 20 chars. Each parameter: 100 chars.
- Empty parameters are still separators: `BLOCK|12|||||admin@test.com`.
- Responses start with `SUCCESS|<TAG>|…` or `ERROR|<CODE>|<detail>?`; the
  gateway maps codes to HTTP status and `{ data: [...] }` / `{ error: … }`.
- The SQL bridge accepts at most **6 binds** per statement. Use
  `SQL_PREPARE_EXEC_ROWS` for multi-row results.
- Dispatch is by action prefix in `main_logic.cob` (for example `CARD_*` →
  `card_core`). Adding an action means: paragraph in the module, dispatch entry
  if the prefix is new, route, tests, then regenerate the manifest.

Two runtime modes:

```sh
./cobol/bin/main_logic            # file mode: input.txt → output.txt
./cobol/bin/main_logic --serve    # one request per stdin line, one result per line
```

## Quick start

Prerequisites: GnuCOBOL (`cobc`), `gcc`, `libmysqlclient-dev`, MariaDB/MySQL with
the client, and Node.js 18+ with npm.

```sh
# 1. Database (fresh install)
mysql -u root -e "CREATE DATABASE IF NOT EXISTS cobol_db CHARACTER SET utf8mb4;"
mysql -u root cobol_db < database/schema.sql
mysql -u root cobol_db < database/seed_test_data.sql   # dev fixtures, re-runnable
./database/migrate.sh                                  # apply recorded migrations

# 2. Build the COBOL binary
./build.sh

# 3. Smoke test
printf 'PING||||||\n' > input.txt
./cobol/bin/main_logic
cat output.txt        # SUCCESS|PONG

# 4. Gateway
cp middleware/.env.example middleware/.env
npm --prefix middleware install
npm --prefix middleware start          # PORT from middleware/.env, default 3000

# 5. Full local gate
./ci.sh                                # must end with RUN_ALL (full) GREEN
```

Defaults point at `cobol_user` / `cobol_pass` / `cobol_db`. Override with
`tests/.dbenv` (gitignored) for tests and with `middleware/.env` for the
gateway. For an isolated local test database (recommended: no risk to the
developer database), see [docs/TESTING.md](docs/TESTING.md)
(`docker-compose.test.yml` on port 3307 plus `scripts/dev/setup-test-db.sh`).
For production, `database/grants.sh` provisions separate DML-only
(`cobol_app`) and migration (`cobol_migrate`) accounts.

The seed fixtures create `sender@test.com`, `receiver@test.com`, and
`admin@test.com` (`SUPER_ADMIN`). Their seeded password hashes are placeholders,
so use the signup/verify/login flow for real tokens.

## HTTP gateway

Authentication is bearer-token based: a short-lived JWT access token plus a
rotating refresh token. Privileged writes also require a step-up proof issued by
`POST /auth/step-up` and sent in `X-Step-Up`. The acting identity always comes
from the token, never from the request body. TOTP MFA is supported.

Public authentication endpoints:

| Method | Path | Action |
| --- | --- | --- |
| POST | `/auth/signup` | `REQUEST_SIGNUP` |
| POST | `/auth/verify` | `VERIFY_EMAIL` |
| POST | `/auth/login` | `AUTH_LOGIN` |
| POST | `/auth/refresh` | refresh-token rotation (transport only) |
| POST | `/auth/forgot` | `FORGOT_PASSWORD` |
| POST | `/auth/reset-password` | `RESET_PASSWORD` |
| POST | `/auth/resend` | `RESEND_VERIFICATION` |

Authenticated session endpoints:

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/auth/step-up` | `VERIFY_REAUTH` → short-lived `X-Step-Up` proof |
| POST | `/auth/logout` | revoke the presented refresh session |

Operational endpoints:

- `GET /health` — deep health check (COBOL/DB round-trip), public.
- `GET /live` — liveness (process up, no dependencies), public.
- `GET /ready` — dependency check (cached), public.
- `GET /metrics` — Prometheus text; requires an `AUDIT_READ` bearer token.

Route groups cover identity and access, wallet/ledger, payments and
holds, lending (`/loans`, `/loan-schedules`), deposits, cards, GL and period
close, fees, reports and delivery, imports, reconciliation, disputes, KYC and
screening, compliance/legal holds, audit, alerts, on-call, batch/EOD, reference
data, and backup/DR. Every route field must declare a `RegExp` pattern; a guard
test fails the suite otherwise.

### Configuration

All gateway settings live in `middleware/.env` (fully documented in
`middleware/.env.example`). The most important ones:

| Variable | Purpose |
| --- | --- |
| `PORT`, `NODE_ENV` | HTTP port; production enables strict startup checks |
| `JWT_SECRET`, `REFRESH_SECRET` | Separate secrets, ≥32 chars, must differ |
| `COBOL_BIN` | Override the binary path |
| `COBOL_POOL_SIZE`, `COBOL_POOL_PIPELINE`, `COBOL_POOL_TIMEOUT_MS`, `COBOL_POOL_QUEUE_MAX` | Worker pool; production defaults to 4 workers × 2 in-flight |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASS`, `DB_NAME` | Inherited by the C bridge |
| `REDIS_URL`, `TRUST_PROXY` | Shared rate-limit counters; trusted proxy hops |
| `RATE_LIMIT_*`, `API_RATE_LIMIT_*`, `JSON_BODY_LIMIT` | Request protection |
| `SMTP_*`, `OUTBOX_*` | Verification mail and outbox dispatch |
| `METRICS_PUSH_URL`, `METRICS_PUSH_INTERVAL_MS` | Optional metrics push |
| `TRANSFER_MAX_PER_TXN`, `TRANSFER_DAILY_LIMIT`, `PENDING_RETENTION_DAYS` | Core-enforced limits |

Production startup refuses weak/default JWT secrets and default DB credentials.
Verification codes are queued in a transactional outbox; the dispatcher is:

```sh
node middleware/workers/outbox.js --once --limit 100
```

## Database

- `database/schema.sql` — baseline snapshot, fresh installs only.
- `database/migrations/` — append-only, one file per change (`0101_…` …
  `0110_cards.sql`), tracked in `schema_migrations`.
- `database/migrate.sh` — idempotent runner; `--check` lists pending versions,
  `--only <version>` applies one.
- `database/seed_test_data.sql` — deterministic development fixtures.
- `database/grants.sh` — least-privilege runtime account and privileged
  migration account (`--print` to review).

Never edit an applied migration: add a new file. Migrations run under the
privileged account; the running application only needs DML rights.

## Tests

```sh
tests/run_all.sh fast     # manifest + build + COBOL table cases + PING smoke
tests/run_all.sh db       # schema + all DB suites (isolated, see docs/TESTING.md)
tests/run_all.sh full     # fast + db + COBOL/C error harness + gateway suite
tests/run_all.sh probes   # break the code on purpose; require the gates to notice
./ci-fast.sh              # wrapper for fast
./ci.sh                   # wrapper for full
```

| Suite | Assertions (2026-11-05, see `tests/baseline_counts.txt`) | Location |
| --- | ---: | --- |
| COBOL table cases | 320 | `tests/cobol/cases/*.cases` (60 files) |
| Schema / migrations | 76 | `tests/db/schema_tests.sh` |
| D1 loan schedule | 33 | `tests/db/loan_schedule_db_tests.sh` |
| D2 deposit | 30 | `tests/db/deposit_db_tests.sh` |
| D3 card | 38 | `tests/db/card_db_tests.sh` |
| D4 collections | 35 | `tests/db/collection_db_tests.sh` |
| D5 payments | 20 | `tests/db/payment_clearing_db_tests.sh` |
| D6 treasury | 18 | `tests/db/treasury_liquidity_db_tests.sh` |
| D8 gl allocation | 13 | `tests/db/gl_allocation_db_tests.sh` |
| D9 backup drill | 13 | `tests/db/backup_drill_db_tests.sh` |
| D10 report builder | 13 | `tests/db/report_builder_db_tests.sh` |
| Gateway | 151 `test()` blocks (`tests/baseline_counts.txt`: `gateway_tests=205` at runtime) | `middleware/test/*.js` |

Table cases are one line each: `name@@expected-regex@@ACTION|P1|…|P6`. Database
suites fail closed with `FAIL: DB unavailable` when MariaDB is not reachable
(`ALLOW_SKIP=1` opts out locally; CI never sets it), create their own
fixtures, and reset their tables before running. `tests/run_all.sh db` runs
the DB fleet in an isolated throwaway database and refuses to run against
`cobol_db` without DDL-capable migrate credentials unless `ALLOW_DEV_DB=1`
is set; see [docs/TESTING.md](docs/TESTING.md) for the local setup
(Docker Compose on port 3307), the safety model, and troubleshooting. The hosted CI job
starts an empty MariaDB service, applies every migration, then runs the same
full gate; `SKIP_BUILD=1` reuses the binary from the build job. Locally the
suites are repeatable against one database: `tests/run_all.sh full` must stay
green on a second run. `tests/baseline_counts.txt` records the expected totals;
update it only when a test count changes intentionally.

Core modules have a warning ratchet: `scripts/check_warnings.sh <build.log>`
fails when a counted file in `tests/warning_baseline.txt` gains a warning. Lower
the baseline as warnings are fixed; add each new domain module with its current
count (ideally zero).

The error harness (`tests/check_cobol_c_errors.sh`) checks COBOL/C syntax,
linkage, a PING run, DB connectivity, and non-empty output. The gateway suite
covers auth and refresh rotation, security, validation, route coverage, IPC in
both modes, pool config/failure handling, rate limiting, mailer, and
observability.

## Manifest

`manifest/modules.json` is the single registry of COBOL modules, gateway route
files, and dispatcher prefixes. It is generated, never hand-edited:

```sh
node scripts/generate_manifest.mjs
node scripts/check_manifest.mjs     # fails on drift; run in CI
```

`check_manifest.mjs` verifies that every module is compiled by `build.sh`, that
route files are exported from `routes/index.js`, and that dispatch entries match
`main_logic.cob`.

## Operations

- Structured JSON logs; responses carry `X-Request-Id` and `X-Cobol-Ms`.
- `monitoring/prometheus-alerts.yml` covers gateway 5xx rate, pool saturation,
  pool restarts, and related signals.
- `/metrics` exposes request, error, auth-failure, and pool gauges/counters.
- Graceful pool shutdown and restart handling live in `middleware/src/pool.js`.
- `backups/` is gitignored and holds local physical-backup output only.

## Known gaps

1. **Generated-domain depth varies by tier.** Every module implements the
   9-action contract (`docs/module_authoring.md`), but Tier-2 modules follow the
   `cost_center_core` template closely. Treat the domain table above as the
   hand-reviewed flagship set; the full inventory is `manifest/modules.json`.
   Tier definitions and strictness live in `docs/module_classification.md`.
2. **Copy-paste plumbing.** Boilerplate paragraphs (`TRIM-ALL`, `VALIDATE-ALL`,
   `TRIM-RESULT-LEN`) are repeated across most generated modules. Shared
   copybooks for trimming, validation, and audit are the main refactor target.
3. **CI is hosted on GitHub Actions, but branch protection is unavailable.**
   The private/free plan rejects branch protection and repository rulesets, so
   merges are enforced by `scripts/ci/premerge.sh` and `docs/GOVERNANCE.md`
   rather than by the GitHub UI.
4. **Documentation is maintained but generated in places.** `docs/STATUS.md`
   and `docs/MODULE_INDEX.md` are generated from the manifest; ADRs, runbooks,
   coverage, governance, the data dictionary, and the domain overview are
   hand-maintained. Run `node scripts/check_docs.mjs` before merging.
5. **Legacy compiler warnings** remain in some non-D1–D3 modules.
6. **Build cost.** `./build.sh` compiles the full COBOL tree and takes several
   minutes; `tests/run_all.sh full` is the slow, authoritative gate.

## Working in this repository

1. Branch from `main`; keep one domain or concern per PR.
2. Put business rules and SQL in the relevant `cobol/src/*_core.cob`, using
   `SQL_BEGIN`/`SQL_COMMIT`/`SQL_ROLLBACK`, `GET_RESULT`, `ALLOW-ADMIN`, and
   `AUDIT` in the established pattern.
3. Add the schema change as a new migration; never modify `schema.sql` by hand
   for an incremental change.
4. Add the route with fields in the exact COBOL parameter order, static paths
   before `/:id`, and a `PATTERNS` entry for every named field.
5. Add table cases and a DB suite for the new behaviour.
6. Regenerate and check the manifest, then run `./ci.sh`.
7. Update `tests/baseline_counts.txt` only for intentional count changes.

### Command cheat sheet

```sh
./build.sh                              # rebuild the COBOL binary
tests/cobol/table_runner.sh             # all table cases
tests/cobol/table_runner.sh tests/cobol/cases/card.cases
tests/db/card_db_tests.sh               # one DB suite
npm --prefix middleware test            # gateway suite
node scripts/check_manifest.mjs         # registry drift check
node middleware/workers/outbox.js --once
```

## Documentation

- [Repository status](docs/STATUS.md) — generated counts.
- [Module index](docs/MODULE_INDEX.md) — every registered module, prefix, route, cases, and DB suite.
- [Domain overview](docs/domain_overview.md) and [data dictionary](docs/data_dictionary.md).
- [Coverage](docs/COVERAGE.md), [governance](docs/GOVERNANCE.md), and [secret rotation runbook](docs/runbooks/secret-rotation.md).
- [Architecture decision records](docs/adr/).

Run `node scripts/check_docs.mjs` to verify generated stats and local links.

## License

This repository is proprietary and confidential. Copyright (c) 2026
Muhammad Febriansyah. All rights reserved. No license, express or implied, is
granted to use, copy, modify, distribute, or sublicense this software without
prior written permission. See `LICENSE`.

## Governance

Branch protection is unavailable on the current private/free GitHub plan. The
approved exception and compensating controls are documented in
`docs/GOVERNANCE.md`. Run `bash scripts/ci/premerge.sh` before opening a pull
request.
