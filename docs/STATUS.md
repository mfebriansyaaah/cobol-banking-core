# STATUS.md - Current state of the project

Snapshot of the running system as of 2026-10-11. Every factual claim here is
verifiable: suite counts by running `./ci.sh`, action names by grepping
`cobol/src/`, and the cross-references by `tests/status_check.sh` (wired into
`ci.sh`).

## 1. What this is

A banking core where **all business logic lives in COBOL**:
- `cobol/bin/main_logic` - one binary that reads a single pipe-delimited
  request line from `input.txt` and writes one result line to `output.txt`
  (`ACTION|param1|param2|param3|param4`), relative to its working directory.
- `middleware/` - a Node.js/Express **API gateway** that is the only HTTP
  interface; it validates input shapes, invokes the binary per request in a
  unique working directory, and maps the result line to HTTP (ADR-0001).
- MySQL database `cobol_db`; the binary talks to it through the C bridge
  `cobol/src/sql_bridge.c` (libmysqlclient - the ODBC stack was retired, ADR-0002).
- `./ci.sh` - one-shot verification: docs integrity, static COBOL checks
  (period-in-IF, GOBACK placement, router prefix collisions, router/owner
  agreement, `users(email)` FK cascade, gateway action coverage), build, the
  shell suites (functional, transactional, security, prepared-statement,
  migration), the API-gateway node suite, and an end-to-end HTTP smoke against a
  live gateway. Must exit 0 with `ALL GREEN`.

## 2. Modules and actions (current behavior)

| Module | Action | Params | Behavior | Outputs |
|---|---|---|---|---|
| `cobol/src/wallet_core.cob` | `CHECK_BALANCE` | email, actor (self-or-admin) | ledger-backed? no: `accounts.balance` (`CONCAT(ROUND(...,2))`) | `<amount>` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|FORBIDDEN` |
| `cobol/src/wallet_core.cob` | `TRANSFER` | from (token identity), target, amount, **idempotency key** (opt) | one transaction: replay only when sender/target/amount match the committed key; `FOR UPDATE` lock; debit/credit; 2 `ledger` rows; `audit_trail`; intent `COMMITTED` | `SUCCESS\|TRANSFER_OK` * `ERROR\|INSUFFICIENT_FUNDS` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|TARGET_NOT_FOUND` * `ERROR\|TRANSFER_IN_PROGRESS` * `ERROR\|IDEMPOTENCY_CONFLICT` * `ERROR\|INVALID_AMOUNT` * `ERROR\|CURRENCY_MISMATCH` * `ERROR\|DB_ERROR` |
| `cobol/src/wallet_core.cob` | `RECONCILE` | actor (SUPER_ADMIN) | lists accounts where `accounts.balance <> SUM(ledger)` | `SUCCESS\|RECONCILED` * `ERROR\|MISMATCH\|...` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `GET_USER` | email, actor (self-or-admin) | `SELECT id, email WHERE email` | `<id>\|<email>` * `ERROR\|NOT_FOUND` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `LIST_USERS` | limit(20), offset(0), actor (admin) | paged, rows via `SQL_PREPARE_EXEC_ROWS` | `SUCCESS\|LIST_DONE\|<id:email;...>` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `GET_DASHBOARD` | email, actor (self-or-admin) | email, full name, **all** accounts as `iso:balance;...` | `SUCCESS\|DASHBOARD\|...` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `REQ_EMAIL_CHANGE` | current, new, actor (owner) | 6-digit code stored against the new email | `SUCCESS\|CODE_SENT\|<code>` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|EMAIL_EXISTS` * `ERROR\|EMAIL_CHANGE_FAILED` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `CONFIRM_EMAIL_CHANGE` | current, new, code, actor (owner) | consume code, move email, audit | `SUCCESS\|EMAIL_CHANGED` * `ERROR\|INVALID_CODE` * `ERROR\|EMAIL_CHANGE_FAILED` * `ERROR\|FORBIDDEN` |
| `cobol/src/auth_core.cob` | `REQUEST_SIGNUP` | email, password, name, dob | 8-char min password, unique email, PBKDF2 hash, 6-digit code in `verification_logs`; audit row | `SUCCESS\|USER_CREATED\|<code>` * `ERROR\|WEAK_PASSWORD` * `ERROR\|EMAIL_EXISTS` * `ERROR\|SIGNUP_FAILED` |
| `cobol/src/auth_core.cob` | `VERIFY_EMAIL` | email, code | consume code, set `VERIFIED`, transactional; audit success or (attributable) failure | `SUCCESS\|EMAIL_VERIFIED` * `ERROR\|INVALID_CODE` * `ERROR\|VERIFY_FAILED` |
| `cobol/src/auth_core.cob` | `AUTH_LOGIN` | email, password | 3-fail/15-min lockout; PBKDF2 verify w/ legacy SHA256 fallback + rehash; must be `VERIFIED` | `SUCCESS\|LOGIN_OK` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|INVALID_CREDENTIALS` * `ERROR\|UNVERIFIED` * `ERROR\|ACCOUNT_LOCKED` |
| `cobol/src/auth_core.cob` | `CHECK_ROLE` | email, role, actor (self-or-admin) | does the user hold the role | `SUCCESS\|ROLE_OK` * `ERROR\|ROLE_DENIED` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|FORBIDDEN` |
| `cobol/src/auth_core.cob` | `CHANGE_ROLE` | target, role, actor(actor must be SUPER_ADMIN) | transactional update + audit | `SUCCESS\|ROLE_CHANGED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_ROLE` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|ROLE_CHANGE_FAILED` |
| `cobol/src/auth_core.cob` | `STORE_SESSION` | jti, email, days | record a refresh-token session | `SUCCESS\|SESSION_STORED` * `ERROR\|SESSION_STORE_FAILED` |
| `cobol/src/auth_core.cob` | `REVOKE_SESSION` | jti | revoke a refresh token | `SUCCESS\|SESSION_REVOKED` * `ERROR\|SESSION_REVOKE_FAILED` |
| `cobol/src/auth_core.cob` | `CHECK_SESSION` | jti | is the refresh token still valid | `SUCCESS\|SESSION_VALID` * `ERROR\|SESSION_REVOKED` |
| `cobol/src/auth_core.cob` | `PING` | - | deep health: DB reachability | `SUCCESS\|PONG` * `ERROR\|DB_DOWN` |

The routing contract lives in `AGENTS.md`; `ci.sh` verifies every routed
action has a handler in its owning module.

## 3. Database (`cobol_db`)

Tables in `database/schema.sql` (v1.5.0):
`users` * `currencies` * `exchange_rates` * `accounts` * `ledger` *
`verification_logs` * `audit_trail` * `pending_transactions` * `refresh_sessions` (jti + `family`) * `schema_migrations`
(transfer intents, `PENDING`->`COMMITTED`, cascaded on user delete -
`database/migrations/0001_*.sql`).

The bridge reads its connection from the environment
(`DB_HOST`/`DB_PORT`/`DB_USER`/`DB_PASS`/`DB_NAME`, with development
defaults); no credentials are compiled into the source. The gateway passes its
own environment (see `middleware/.env.example`) to the binary it spawns.

Migrations applied by `database/migrate.sh` and tracked in `schema_migrations`; `database/migrate.sh --check` verifies none are pending. Seed data: `database/seed_test_data.sql`.

## 4. Test suites (all green under `./ci.sh`)

| Suite | Count | Covers |
|---|---:|---|
| `tests/test_suite.sh` | 13 | functional surface (actions, defaults, idempotent replay error mapping) |
| `tests/test_atomic_txn.sh` | 5 | atomic transfer contract (file-based I/O) |
| `tests/test_ledger_atomic.sh` | 17 | atomicity: ledger rows, rollback on every failure path, audit row |
| `tests/test_reconciliation.sh` | 10 | `RECONCILE` on healthy/drifted states; SUPER_ADMIN actor gate |
| `tests/test_auth_login.sh` | 6 | login, legacy rehash on login |
| `tests/test_signup_verify.sh` | 20 | signup + verify flow, PBKDF2 hash, uniqueness, success + failed-verify audit |
| `tests/test_roles.sh` | 13 | `CHECK_ROLE` self-or-admin + `CHANGE_ROLE` SUPER_ADMIN gate |
| `tests/test_user_profile.sh` | 17 | dashboard multi-account, paging, email-change |
| `tests/test_login_lockout.sh` | 7 | 3-fail lockout, audit rows, clearing |
| `tests/test_idempotent_transfer.sh` | 20 | replay-no-op, key reuse conflict, distinct keys, failure retry |
| `tests/test_transfer_validity.sh` | 10 | positive-amount and same-currency rules |
| `tests/test_injection.sh` | 9 | auth values escaped (accepted literally); user/wallet still whitelist-only |
| `tests/test_session.sh` | 8 | STORE/CHECK/REVOKE_SESSION lifecycle + reuse detection (family revocation) |
| `tests/test_prepared.sh` | 15 | signup/login/transfer/reconcile (`SQL_PREPARE_EXEC`), locking read (`SQL_PREPARE_EXEC_LOCK`) and list (`SQL_PREPARE_EXEC_ROWS`) through prepared statements |
| `tests/test_ping.sh` | 3 | deep-health PING reaches the DB; connection settings come from the environment |
| `tests/test_migrate.sh` | 6 | migration runner idempotent; --check detects pending |
| `tests/test_concurrent_transfer.sh` | 4 | opposing concurrent transfers all succeed, money conserved |
| `tests/test_e2e_gateway.sh` | 19 | live-gateway HTTP flow: signup→verify→login→transfer→refresh→metrics→logout |
| `middleware/` (node --test) | 38 | gateway: contract, injection, rate limit (auth + api), refresh reuse, timeout, line cap, every-endpoint smoke, actor-token guard, observability, idempotency conflict, security headers/config |

Shell suites total **210**; with the gateway suite **38** the full run is
**248 assertions**, all green as of this snapshot.

## 5. Gateway surface (`middleware/`)

Held by a bearer JWT (public: `/health`, `/auth/signup`, `/auth/verify`,
`/auth/login`, `/auth/refresh):
`/users`, `/users/:email`, `/wallet/balance`, `/wallet/transfer`
(`Idempotency-Key`), `/profile`, `/profile/email/request`,
`/profile/email/confirm`, `/admin/role` (GET/POST), `/admin/reconcile`
(read-only balance/ledger check), `/metrics` (Prometheus counters, bearer),
`/auth/logout` (revokes a refresh token).
Both admin routes (`/admin/role` POST, `/admin/reconcile`) take the actor from
the verified token, never the request body. The per-user reads (`/users/:email`,
`/wallet/balance`, `/profile`) and the role check `GET /admin/role` allow the
owner or an admin; `/users` (list) is
admin-only. Writes are owner-scoped too: a transfer is always sent from the
token's account, and the email-change flow only acts on the token's own email.
Actor/sender identity always comes from the token.
Status mapping: 200 on `SUCCESS`; 400/401/403/404/409/423/429/500/504 by error
code (see `middleware/src/result.js`). Input-line cap 500 bytes; fixed-window
rate limiting per client (`RATE_LIMIT_*` on `/auth/*`, more generous
`API_RATE_LIMIT_*` on the rest; `/health` exempt); access token 15m + refresh 7d
(`middleware/.env.example`). Every response carries `X-Request-Id`, and the
server logs one JSON line per request (`event: http_request` with method, route,
status, `durationMs`, `cobolMs`); counters are served at `/metrics`.
`helmet` sets standard security headers, and in production the server refuses to
start while JWT_SECRET/REFRESH_SECRET are unset or still the development
defaults.

## 6. Governance documents

- `docs/HISTORY.md` - every merged phase, its commits, and date (regenerate with `docs/gen_history.sh`).
- `docs/adr/0001-invocation-model.md`, `docs/adr/0002-auth-db-stack.md`, `docs/adr/0003-idempotent-transfers.md` - decisions.
- `CODING_STANDARDS.md` - review rules.
- `scripts/install-hooks.sh` - installs a pre-commit hook that blocks commits on `main`.

## 7. Known gaps (deliberate, by scale)

- Password KDF is PBKDF2-SHA256 (100k iters); legacy `SHA256_` fallback stays until all accounts rehash.
- Transfers must be positive and within one currency; cross-currency is rejected (`CURRENCY_MISMATCH`) until an FX path exists.
- Email change updates `users.email`; related FKs (`refresh_sessions`, `pending_transactions`) cascade on update (migrations 0003 and 0004, which repairs a 0001/0003 ordering regression), so a logged-in user with a transfer intent can still change their email.
- Prepared statements now cover every query in `auth_core`, `user_core` and `wallet_core` (including the parameterless `RECONCILE` scan). The locking `SELECT ... FOR UPDATE` uses `SQL_PREPARE_EXEC_LOCK` (bound params, no row fetch) because reading its result via `mysql_stmt_store_result` makes MariaDB raise `ER_CHECKREAD` (1020) under contention. Prepared SQL is bounded at 1023 chars (`WS-PREP-SQL` `PIC X(1024)`).
- `audit_trail` records `REQUEST_SIGNUP` (SUCCESS), `VERIFY_EMAIL` (SUCCESS, and FAILED for a bad/expired/reused code when the email belongs to a user; unattributable attempts are skipped), `AUTH_LOGIN_FAILED`, `TRANSFER`, `EMAIL_CHANGE`, and `CHANGE_ROLE`. Refresh tokens are single-use and rotate within a `family`; presenting an already-revoked token is treated as reuse and revokes the whole family (all sessions for that login), so a stolen token cannot be replayed.
- One-line COBOL result bounds large lists; process-per-request limits throughput (revisit ADR-0001 at scale).
