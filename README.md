# Cobol Banking Core

A banking backend where **COBOL is the authoritative business tier**. Every
balance, limit, status transition, and ledger mutation is decided and executed
in COBOL. Node/Express is only the HTTP gateway (routing, input-shape
validation, authentication), and C provides the MySQL bridge plus the low-level
crypto helpers COBOL cannot call directly.

[![CI](https://github.com/mfebriansyaaah/cobol-banking-core/actions/workflows/ci.yml/badge.svg)](https://github.com/mfebriansyaaah/cobol-banking-core/actions/workflows/ci.yml)

> **Status (2026-10-27):** engineering codebase, not a production certification.
> All 120 domain COBOL modules carry real SQL-backed logic; only
> `auth_password_core` and `hashlen_core` are utility modules.
> `tests/run_all.sh full` is green locally and in the hosted CI gate.
> Treat the numbers below as measurements of this repository,
> not as a readiness claim.

## Architecture

```
Client
  │  HTTPS / JSON
  ▼
middleware/                     Node 18+ / Express 4
  app.js                       route table: HTTP → COBOL action
  routes/*.js                  per-domain field order + patterns
  validation.js                request shape, no business rules
  auth.js                      JWT access/refresh, MFA, step-up
  invoker.js + pool.js         file mode or warm worker pool
  │  pipe protocol: ACTION|P1|P2|P3|P4|P5|P6
  ▼
cobol/bin/main_logic            GnuCOBOL, one binary
  main_logic.cob               prefix dispatch (179 entries)
  *_core.cob                   business logic + transactional SQL
  │  SQL_BEGIN / SQL_PREPARE_EXEC / SQL_PREPARE_EXEC_ROWS / SQL_COMMIT
  ▼
cobol/src/sql_bridge.c          MySQL C API prepared statements
  ▼
MariaDB / MySQL — database `cobol_db`
```

Rules of the split:

- **COBOL** owns domain rules: authorization, limits, status machines,
  idempotency, currency checks, interest, fees, and every write.
- **JavaScript** owns transport: URL parsing, regex validation, JWT/MFA,
  rate limits, and mapping `SUCCESS|…` / `ERROR|CODE|…` to HTTP.
- **C** owns database connectivity (`sql_bridge.c`) and the crypto/settings
  primitives in `cobol/c_lib/`.

## Repository layout

| Path | Contents |
|---|---|
| `cobol/src/` | 112 domain modules + `main_logic.cob` dispatcher + `sql_bridge.c` |
| `cobol/copy/` | Three copybooks used only by the password/auth module |
| `cobol/c_lib/` | PBKDF2, TOTP, CSPRNG, settings helpers |
| `cobol/bin/` | Build output (`main_logic`), gitignored |
| `middleware/src/` | Express gateway (88 files, 87 route modules + barrel) |
| `middleware/test/` | 16 test files, 136 tests |
| `database/` | `schema.sql` baseline (477 tables), 111 migrations, seed, grants |
| `tests/` | Unified runner, table-driven COBOL cases, DB suites, harness |
| `manifest/modules.json` | Generated registry: 112 modules, 87 route files, 188 dispatch entries |
| `scripts/` | `generate_manifest.mjs`, `check_manifest.mjs` |
| `monitoring/` | Prometheus alert rules for the gateway |
| `build.sh` | Compiles dispatcher + all 112 modules + C bridge |
| `.github/workflows/ci.yml` | Hosted CI: build + warning ratchet, then full test gate |
| `ci.sh`, `ci-fast.sh` | Local CI entry points |

## Implementation status

| Domain | Status | Modules |
|---|---|---|
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

### Known gaps (2026-10-27)

- `middleware/src/routes/loan.js` exposes `LOAN_APPLY`, `LOAN_APPROVE`, `LOAN_REJECT`,
  `LOAN_DISBURSE`, and `LOAN_REPAY`, but the COBOL `loan_core` module does not implement
  those actions yet (they return `ERROR|INVALID_ACTION`). Use `loan_schedule_core` (`LSC_*`)
  for schedule operations until the loan application lifecycle is implemented.
- `auth_core.cob` still carries 922 compiler warnings; `wallet_core.cob` cleanup is in progress.

## Testing workflow roadmap

Testing maturity: **9/10** (achieved). All 11 roadmap items complete.

| Priority | Improvement | Effort | Expected gain |
|---|---|---|---|
| ✅ P0 | **Code coverage tracking** — run `cobc --coverage` and `node --test-coverage` in CI; gate on minimum thresholds | 2d | Know exactly what is untested |
| ✅ P0 | **CI speed** — split compile into incremental steps or use `ccache`-style caching; target <2 min | 1d | Faster feedback loop |
| ✅ P1 | **Integration tests across domains** — scenarios that exercise loan → collection → payment → treasury flow | 3d | Catch cross-domain contract breaks |
| ✅ P1 | **Gateway test isolation** — each test file seeds its own data into a unique schema / connection | 2d | Eliminate flaky failures |
| ✅ P1 | **Reduce warning baseline to 0** — fix all `-Wconstant-expression`, `-Wpossible-truncate` etc. | 1d | Clean compile, catch new issues |
| ✅ P2 | **Performance benchmarks** — COBOL action latency P50/P99 in CI | 2d | Detect regressions early |
| ✅ P2 | **Mutation testing** — verify tests actually kill mutants | 3d | Test quality gate |
| ✅ P2 | **SAST scan** — static analysis for SQL injection, auth bypass patterns | 1d | Security baseline |
| ✅ P3 | **Property-based / fuzz testing** — random input validation for every COBOL action | 2d | Edge-case coverage |
| ✅ P3 | **Smoke test for skeleton modules** — verify they return `INVALID_ACTION` instead of crashing | 0.5d | Prevent runtime surprises |
| ✅ P3 | **Post-merge CI** — deploy migration dry-run / rollback drill | 1d | Safer deployments |

Measured on this checkout:

| Metric | Value |
|---|---:|
| COBOL files | **123** (122 modules + dispatcher) |
| COBOL lines | **88,767** |
| Modules with real logic | **120** domain modules (all modules except the 2 utilities below) |
| Utility modules | **2** — `auth_password_core`, `hashlen_core` (delegate to auth_core / hash_lib) |
| Skeleton modules | **0** — every domain module now carries real SQL-backed logic |
| Gateway route definitions | **985** unique actions across **118** route files |
| COBOL dispatch prefixes | **189** |
| Database tables (`schema.sql`) | **478** |
| Recorded migrations | **147** (latest `0147_loan_hardening`) |
| Test assertions | **508+** (179 table + 76 schema + 253 gateway, plus 35 DB suites) |

## Request contract

The gateway and the binary speak one line per request:

```
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
gateway. For production, `database/grants.sh` provisions separate DML-only
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
|---|---|---|
| POST | `/auth/signup` | `REQUEST_SIGNUP` |
| POST | `/auth/verify` | `VERIFY_EMAIL` |
| POST | `/auth/login` | `AUTH_LOGIN` |
| POST | `/auth/refresh` | refresh-token rotation (transport only) |
| POST | `/auth/forgot` | `FORGOT_PASSWORD` |
| POST | `/auth/reset-password` | `RESET_PASSWORD` |
| POST | `/auth/resend` | `RESEND_VERIFICATION` |

Authenticated session endpoints:

| Method | Path | Purpose |
|---|---|---|
| POST | `/auth/step-up` | `VERIFY_REAUTH` → short-lived `X-Step-Up` proof |
| POST | `/auth/logout` | revoke the presented refresh session |

Operational endpoints:

- `GET /health` — liveness, public.
- `GET /ready` — dependency check (cached), public.
- `GET /metrics` — Prometheus text; requires an `AUDIT_READ` bearer token.

Route groups (86 modules) cover identity and access, wallet/ledger, payments and
holds, lending (`/loans`, `/loan-schedules`), deposits, cards, GL and period
close, fees, reports and delivery, imports, reconciliation, disputes, KYC and
screening, compliance/legal holds, audit, alerts, on-call, batch/EOD, reference
data, and backup/DR. Every route field must declare a `RegExp` pattern; a guard
test fails the suite otherwise.

### Configuration

All gateway settings live in `middleware/.env` (fully documented in
`middleware/.env.example`). The most important ones:

| Variable | Purpose |
|---|---|
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
node middleware/src/outbox_worker.js --once --limit 100
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
tests/run_all.sh db       # schema + D1-D4 database suites
tests/run_all.sh full     # fast + db + COBOL/C error harness + gateway suite
./ci-fast.sh              # wrapper for fast
./ci.sh                   # wrapper for full
```

| Suite | Assertions | Location |
|---|---:|---|
| COBOL table cases | 27 | `tests/cobol/cases/*.cases` |
| Schema / migrations | 76 | `tests/db/schema_tests.sh` |
| D1 loan schedule | 11 | `tests/db/loan_schedule_db_tests.sh` |
| D2 deposit | 26 | `tests/db/deposit_db_tests.sh` |
| D3 card | 32 | `tests/db/card_db_tests.sh` |
| D4 collections | 35 | `tests/db/collection_db_tests.sh` |
| D5 payments | 20 | `tests/db/payment_clearing_db_tests.sh` |
| D6 treasury | 18 | `tests/db/treasury_liquidity_db_tests.sh` |
| D7 kyc periodic | 11 | `tests/db/kyc_periodic_db_tests.sh` |
| D8 gl allocation | 13 | `tests/db/gl_allocation_db_tests.sh` |
| D9 backup drill | 13 | `tests/db/backup_drill_db_tests.sh` |
| D10 report builder | 13 | `tests/db/report_builder_db_tests.sh` |
| Gateway | 136 | `middleware/test/*.js` |

Table cases are one line each: `name@@expected-regex@@ACTION|P1|…|P6`. Database
suites skip with `SKIP: DB unavailable` when MariaDB is not reachable, create
their own fixtures, and reset their tables before running. The hosted CI job
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

1. **D4–D10 are skeletons.** 21 modules × 151 stub actions; routes and tables
   exist, business logic does not.
2. **Copy-paste plumbing.** 585 duplicate paragraph bodies were measured
   (`TRIM-ALL` ×104, `VALIDATE-ALL` ×102, `TRIM-RESULT-LEN` ×84). Shared
   copybooks for trimming, validation, and audit are the main refactor target.
3. **No hosted CI.** GitLab/GitHub Actions is not configured; `ci.sh` is the
   only gate, so it must be run locally before every merge.
4. **Documentation surface is thin.** Earlier references to `docs/*.md`,
   `SPEC-*.md`, and helper scripts were removed because those files are not in
   this repository. This README, `middleware/.env.example`, module comments, and
   the tests are the maintained documentation.
5. **Legacy compiler warnings** remain in some non-D1–D3 modules.
6. **Build cost.** `./build.sh` compiles 114 units and takes roughly 2–3 minutes;
   `tests/run_all.sh full` is the slow, authoritative gate.

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
node middleware/src/outbox_worker.js --once
```
