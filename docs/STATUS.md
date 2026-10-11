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
  agreement), build, 10 test suites, and the API-gateway suite. Must exit 0
  with `ALL GREEN`.

## 2. Modules and actions (current behavior)

| Module | Action | Params | Behavior | Outputs |
|---|---|---|---|---|
| `cobol/src/wallet_core.cob` | `CHECK_BALANCE` | email | ledger-backed? no: `accounts.balance` (`CONCAT(ROUND(...,2))`) | `<amount>` * `ERROR\|ACCOUNT_NOT_FOUND` |
| `cobol/src/wallet_core.cob` | `TRANSFER` | sender, target, amount, **idempotency key** (opt) | one transaction: replay if key committed; `FOR UPDATE` lock; debit/credit; 2 `ledger` rows; `audit_trail`; intent `COMMITTED` | `SUCCESS\|TRANSFER_OK` * `ERROR\|INSUFFICIENT_FUNDS` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|TARGET_NOT_FOUND` * `ERROR\|TRANSFER_IN_PROGRESS` * `ERROR\|INVALID_AMOUNT` * `ERROR\|CURRENCY_MISMATCH` * `ERROR\|DB_ERROR` |
| `cobol/src/wallet_core.cob` | `RECONCILE` | - | lists accounts where `accounts.balance <> SUM(ledger)` | `SUCCESS\|RECONCILED` * `ERROR\|MISMATCH\|...` |
| `cobol/src/user_core.cob` | `GET_USER` | email | `SELECT id, email WHERE email` | `<id>\|<email>` * `ERROR\|NOT_FOUND` |
| `cobol/src/user_core.cob` | `LIST_USERS` | limit(20), offset(0) | paged, rows via `SQL_EXECUTE_ROWS` | `SUCCESS\|LIST_DONE\|<id:email;...>` |
| `cobol/src/user_core.cob` | `GET_DASHBOARD` | email | email, full name, **all** accounts as `iso:balance;...` | `SUCCESS\|DASHBOARD\|...` * `ERROR\|ACCOUNT_NOT_FOUND` |
| `cobol/src/user_core.cob` | `REQ_EMAIL_CHANGE` | current, new | 6-digit code stored against the new email | `SUCCESS\|CODE_SENT\|<code>` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|EMAIL_EXISTS` * `ERROR\|EMAIL_CHANGE_FAILED` |
| `cobol/src/user_core.cob` | `CONFIRM_EMAIL_CHANGE` | current, new, code | consume code, move email, audit | `SUCCESS\|EMAIL_CHANGED` * `ERROR\|INVALID_CODE` * `ERROR\|EMAIL_CHANGE_FAILED` |
| `cobol/src/auth_core.cob` | `REQUEST_SIGNUP` | email, password, name, dob | 8-char min password, unique email, PBKDF2 hash, 6-digit code in `verification_logs` | `SUCCESS\|USER_CREATED\|<code>` * `ERROR\|WEAK_PASSWORD` * `ERROR\|EMAIL_EXISTS` * `ERROR\|SIGNUP_FAILED` |
| `cobol/src/auth_core.cob` | `VERIFY_EMAIL` | email, code | consume code, set `VERIFIED`, transactional | `SUCCESS\|EMAIL_VERIFIED` * `ERROR\|INVALID_CODE` * `ERROR\|VERIFY_FAILED` |
| `cobol/src/auth_core.cob` | `AUTH_LOGIN` | email, password | 3-fail/15-min lockout; PBKDF2 verify w/ legacy SHA256 fallback + rehash; must be `VERIFIED` | `SUCCESS\|LOGIN_OK` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|INVALID_CREDENTIALS` * `ERROR\|UNVERIFIED` * `ERROR\|ACCOUNT_LOCKED` |
| `cobol/src/auth_core.cob` | `CHECK_ROLE` | email, role | does the user hold the role | `SUCCESS\|ROLE_OK` * `ERROR\|ROLE_DENIED` * `ERROR\|ACCOUNT_NOT_FOUND` |
| `cobol/src/auth_core.cob` | `CHANGE_ROLE` | target, role, actor(actor must be SUPER_ADMIN) | transactional update + audit | `SUCCESS\|ROLE_CHANGED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_ROLE` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|ROLE_CHANGE_FAILED` |
| `cobol/src/auth_core.cob` | `STORE_SESSION` | jti, email, days | record a refresh-token session | `SUCCESS\|SESSION_STORED` * `ERROR\|SESSION_STORE_FAILED` |
| `cobol/src/auth_core.cob` | `REVOKE_SESSION` | jti | revoke a refresh token | `SUCCESS\|SESSION_REVOKED` * `ERROR\|SESSION_REVOKE_FAILED` |
| `cobol/src/auth_core.cob` | `CHECK_SESSION` | jti | is the refresh token still valid | `SUCCESS\|SESSION_VALID` * `ERROR\|SESSION_REVOKED` |

The routing contract lives in `AGENTS.md`; `ci.sh` verifies every routed
action has a handler in its owning module.

## 3. Database (`cobol_db`)

Tables in `database/schema.sql` (v1.5.0):
`users` * `currencies` * `exchange_rates` * `accounts` * `ledger` *
`verification_logs` * `audit_trail` * `pending_transactions` * `refresh_sessions`
(transfer intents, `PENDING`->`COMMITTED`, cascaded on user delete -
`database/migrations/0001_*.sql`).

Seed data: `database/seed_test_data.sql`.

## 4. Test suites (all green under `./ci.sh`)

| Suite | Count | Covers |
|---|---:|---|
| `tests/test_suite.sh` | 13 | functional surface (actions, defaults, idempotent replay error mapping) |
| `tests/test_atomic_txn.sh` | 5 | atomic transfer contract (file-based I/O) |
| `tests/test_ledger_atomic.sh` | 17 | atomicity: ledger rows, rollback on every failure path, audit row |
| `tests/test_reconciliation.sh` | 7 | `RECONCILE` on healthy/drifted states |
| `tests/test_auth_login.sh` | 6 | login, legacy rehash on login |
| `tests/test_signup_verify.sh` | 16 | signup + verify flow, PBKDF2 hash, uniqueness, audit |
| `tests/test_roles.sh` | 11 | `CHECK_ROLE`/`CHANGE_ROLE` incl. SUPER_ADMIN gate |
| `tests/test_user_profile.sh` | 17 | dashboard multi-account, paging, email-change |
| `tests/test_login_lockout.sh` | 7 | 3-fail lockout, audit rows, clearing |
| `tests/test_idempotent_transfer.sh` | 15 | replay-no-op, distinct keys, failure retry |
| `tests/test_transfer_validity.sh` | 10 | positive-amount and same-currency rules |
| `tests/test_injection.sh` | 9 | auth values escaped (accepted literally); user/wallet still whitelist-only |
| `tests/test_session.sh` | 5 | STORE/CHECK/REVOKE_SESSION lifecycle |
| `tests/test_concurrent_transfer.sh` | 4 | opposing concurrent transfers all succeed, money conserved |
| `middleware/` (node --test) | 16 | gateway: contract, injection, rate limit, refresh, timeout, line cap |

Shell suites total **142**; with the gateway suite **19** the full run is
**161 assertions**, all green as of this snapshot.

## 5. Gateway surface (`middleware/`)

Held by a bearer JWT (public: `/health`, `/auth/signup`, `/auth/verify`,
`/auth/login`, `/auth/refresh):
`/users`, `/users/:email`, `/wallet/balance`, `/wallet/transfer`
(`Idempotency-Key`), `/profile`, `/profile/email/request`,
`/profile/email/confirm`, `/admin/role` (GET/POST), `/auth/logout` (revokes a refresh token).
Status mapping: 200 on `SUCCESS`; 400/401/403/404/409/423/429/500/504 by error
code (see `middleware/src/result.js`). Input-line cap 500 bytes; auth rate
limit fixed-window; access token 15m + refresh 7d (`middleware/.env.example`).

## 6. Governance documents

- `docs/HISTORY.md` - every merged phase, its commits, and date (regenerate with `docs/gen_history.sh`).
- `docs/adr/0001-invocation-model.md`, `docs/adr/0002-auth-db-stack.md`, `docs/adr/0003-idempotent-transfers.md` - decisions.
- `CODING_STANDARDS.md` - review rules; `AGENTS.md` - steering rules.

## 7. Known gaps (deliberate, by scale)

- Password KDF is PBKDF2-SHA256 (100k iters); legacy `SHA256_` fallback stays until all accounts rehash.
- Transfers must be positive and within one currency; cross-currency is rejected (`CURRENCY_MISMATCH`) until an FX path exists.
- SQL values are escaped via the bridge (`SQL_ESCAPE` -> `mysql_real_escape_string`) in `auth_core`; `user_core`/`wallet_core` remain whitelist-only. Native prepared statements are still outstanding.
- Signup/verify actions are not audited yet; refresh token lacks rotation/denylist.
- One-line COBOL result bounds large lists; process-per-request limits throughput (revisit ADR-0001 at scale).
