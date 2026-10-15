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
  unique working directory, and maps the result line to HTTP (ADR-0001). The
  binary also has a long-running `--serve` mode (stdin/stdout protocol) that a
  **worker pool** uses when COBOL_POOL_SIZE is set (ADR-0010, phase 3); file
  mode stays the default.
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
| `cobol/src/wallet_core.cob` | `CHECK_BALANCE` | email, actor (self-or-admin) | every account as `iso:balance:status` rows (multi-account; `accounts.balance`) | `SUCCESS\|BALANCES\|<iso>:<balance>:<status>[;...]` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|FORBIDDEN` |
| `cobol/src/wallet_core.cob` | `TRANSFER` | from (token identity), target, amount, **idempotency key** (required by the gateway; scoped per sender), fromCurrency/toCurrency (opt) | one transaction: sender **and** target accounts must be `ACTIVE` and both currencies enabled, else rejected; optional per-transaction and rolling 24h debit caps (env); replay only when sender/target/amount match the committed key (unique per sender); `FOR UPDATE` lock; debit sender, credit target (`amount * rate` when currencies differ); 2 `ledger` rows; `audit_trail` (row records `to:amount:currency` in `detail`); intent `COMMITTED` | `SUCCESS\|TRANSFER_OK` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|TARGET_NOT_FOUND` * `ERROR\|ACCOUNT_FROZEN` * `ERROR\|ACCOUNT_CLOSED` * `ERROR\|CURRENCY_INACTIVE` * `ERROR\|INSUFFICIENT_FUNDS` * `ERROR\|LIMIT_EXCEEDED` * `ERROR\|DAILY_LIMIT_EXCEEDED` * `ERROR\|TRANSFER_IN_PROGRESS` * `ERROR\|IDEMPOTENCY_CONFLICT` * `ERROR\|INVALID_AMOUNT` * `ERROR\|RATE_NOT_FOUND` * `ERROR\|SELF_TRANSFER` * `ERROR\|DB_ERROR` * `ERROR\|DB_BUSY` |
| `cobol/src/wallet_core.cob` | `RECONCILE` | actor (SUPER_ADMIN) | lists accounts where `accounts.balance <> SUM(ledger)` | `SUCCESS\|RECONCILED` * `ERROR\|MISMATCH\|...` * `ERROR\|FORBIDDEN` |
| `cobol/src/wallet_core.cob` | `REVERSE_TRANSFER` | ref, actor (SUPER_ADMIN) | one-time compensating reversal: credit the original sender, debit the target (must still hold the credited funds); writes 2 opposite `ledger` rows, a `transfer_reversals` marker and an audit row | `SUCCESS\|TRANSFER_REVERSED` * `ERROR\|FORBIDDEN` * `ERROR\|UNKNOWN_TRANSACTION` * `ERROR\|ALREADY_REVERSED` * `ERROR\|INSUFFICIENT_FUNDS` * `ERROR\|REVERSAL_FAILED` |
| `cobol/src/wallet_core.cob` | `TX_STATUS` | ref, actor (owner or admin), sender (optional, admin) | reports a transfer's status (`COMMITTED`/`PENDING`/`REVERSED`) and parties; an admin may target a sender and the unfiltered result is the newest by id | `SUCCESS\|TRANSFER\|<status>\|<from>\|<to>\|<amount>` * `ERROR\|UNKNOWN_TRANSACTION` |
| `cobol/src/user_core.cob` | `GET_USER` | email, actor (self-or-admin) | full record: id, email, name, status, role, created | `SUCCESS\|USER\|<id>\|<email>\|<name>\|<status>\|<role>\|<created>` * `ERROR\|NOT_FOUND` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `LIST_USERS` | limit(20, gateway caps 1..100), offset(0), actor (admin), role filter (opt) | paged with a total; rows `id:email:name:role:status`; optional role filter | `SUCCESS\|LIST_DONE\|<total>\|<rows>` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `GET_DASHBOARD` | email, actor (self-or-admin) | full profile (email, name, status, role, dob, created) + **all** accounts as `iso:balance;...`; `LEFT JOIN` so users without accounts still get a profile | `SUCCESS\|DASHBOARD\|<email>\|<name>\|<status>\|<role>\|<dob>\|<created>\|<accounts>` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `REQ_EMAIL_CHANGE` | current, new, actor (owner), password | validates both emails, then **re-auth** (password) and **neutral** about the new address: a 6-digit code is stored only when it is free; a taken address returns the same success with no code | `SUCCESS\|CODE_SENT\|<code>` (free) * `SUCCESS\|CODE_SENT` (taken) * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|INVALID_CREDENTIALS` * `ERROR\|INVALID_INPUT` * `ERROR\|EMAIL_CHANGE_FAILED` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `CONFIRM_EMAIL_CHANGE` | current, new, code, actor (owner) | validates emails; consume code, move email, **bump `token_version` + revoke all refresh sessions** (clean re-login), audit; **attempt-capped** (burned after 5 wrong guesses); a new address taken in the meantime is `EMAIL_EXISTS` | `SUCCESS\|EMAIL_CHANGED` * `ERROR\|INVALID_CODE` * `ERROR\|EMAIL_EXISTS` * `ERROR\|INVALID_INPUT` * `ERROR\|EMAIL_CHANGE_FAILED` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `UPDATE_PROFILE` | email, name, actor (owner), dob (opt) | owner-only self-service; validates the email and (when given) the date of birth, then updates `full_name`/`dob` in a transaction with an audit row; blank name is `INVALID_INPUT` | `SUCCESS\|PROFILE_UPDATED` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|INVALID_INPUT` * `ERROR\|PROFILE_UPDATE_FAILED` |
| `cobol/src/user_core.cob` | `DEACTIVATE_ACCOUNT` | email, actor (owner) | owner-only soft-close: sets `status='CLOSED'`, bumps `token_version` and revokes refresh sessions, audited; **refuses when it is the last active SUPER_ADMIN** (`ERROR\|LAST_ADMIN`) | `SUCCESS\|ACCOUNT_DEACTIVATED` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|LAST_ADMIN` * `ERROR\|DEACTIVATE_FAILED` |
| `cobol/src/user_core.cob` | `SET_USER_STATUS` | email, status, actor (admin) | admin sets `UNVERIFIED`/`VERIFIED`/`SUSPENDED`/`CLOSED`; **role hierarchy**: the actor may not be lower-ranked than the target (a MANAGER cannot touch a SUPER_ADMIN; equal ranks are allowed); **refuses to disable the last active SUPER_ADMIN** (`ERROR\|LAST_ADMIN`); bumps `token_version` and revokes refresh sessions, audited | `SUCCESS\|STATUS_CHANGED` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|INVALID_STATUS` * `ERROR\|LAST_ADMIN` * `ERROR\|STATUS_CHANGE_FAILED` |
| `cobol/src/auth_core.cob` | `REQUEST_SIGNUP` | email, password, name, dob | 8-char min password, PBKDF2 hash, 6-digit code in `verification_logs`; audit row; **neutral** when the email is already registered (no account-existence leak) | `SUCCESS\|USER_CREATED\|<code>` (or `SUCCESS\|USER_CREATED` if already registered) * `ERROR\|WEAK_PASSWORD` * `ERROR\|SIGNUP_FAILED` |
| `cobol/src/auth_core.cob` | `VERIFY_EMAIL` | email, code | consume code, set `VERIFIED`, transactional; **attempt-capped** (code burned after 5 wrong guesses); audit success or (attributable) failure | `SUCCESS\|EMAIL_VERIFIED` * `ERROR\|INVALID_CODE` * `ERROR\|VERIFY_FAILED` |
| `cobol/src/auth_core.cob` | `RESEND_VERIFICATION` | email | reissues a fresh `SIGNUP` code only for an existing `UNVERIFIED` account (neutral otherwise) | `SUCCESS\|CODE_SENT\|<code>` (or `SUCCESS\|CODE_SENT` unknown/verified) * `ERROR\|RESEND_FAILED` |
| `cobol/src/auth_core.cob` | `AUTH_LOGIN` | email, password, mfaCode (opt) | 3-fail/15-min lockout tracked on the user row (failed_logins/locked_until) and **masked**: a wrong password stays `INVALID_CREDENTIALS` whether or not the account exists or is locked, only a correct password reveals `ACCOUNT_LOCKED`; PBKDF2 verify w/ legacy SHA256 fallback; **rehash on login** when the stored hash is legacy or below the current cost; when **MFA** is on a valid `mfaCode` (p3) is also required and a bad code is throttled like a bad password; must be `VERIFIED` (a `SUSPENDED`/`CLOSED` account is refused with `USER_SUSPENDED`/`USER_CLOSED`); unknown account returns the same `INVALID_CREDENTIALS` (anti-enumeration, dummy KDF for timing) | `SUCCESS\|LOGIN_OK` * `ERROR\|INVALID_CREDENTIALS` * `ERROR\|UNVERIFIED` * `ERROR\|USER_SUSPENDED` * `ERROR\|USER_CLOSED` * `ERROR\|ACCOUNT_LOCKED` * `ERROR\|MFA_REQUIRED` * `ERROR\|INVALID_MFA` |
| `cobol/src/auth_core.cob` | `MFA_ENROLL_BEGIN` | email, actor (owner) | issues a pending base32 TOTP secret (shown once); rejected if MFA is already on | `SUCCESS\|MFA_SECRET\|<secret>` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|MFA_ALREADY_ENABLED` * `ERROR\|MFA_ENROLL_FAILED` |
| `cobol/src/auth_core.cob` | `MFA_ENROLL_CONFIRM` | email, code, actor (owner) | verifies a TOTP code against the pending secret, then turns MFA on | `SUCCESS\|MFA_ENABLED` * `ERROR\|INVALID_MFA` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|MFA_ENROLL_FAILED` |
| `cobol/src/auth_core.cob` | `MFA_DISABLE` | email, code, actor (owner) | verifies a TOTP code, then clears the secret and turns MFA off | `SUCCESS\|MFA_DISABLED` * `ERROR\|INVALID_MFA` * `ERROR\|MFA_NOT_ENABLED` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|MFA_DISABLE_FAILED` |
| `cobol/src/auth_core.cob` | `FORGOT_PASSWORD` | email | issues a `PASSWORD_RESET` code only when the account exists (neutral otherwise) | `SUCCESS\|CODE_SENT\|<code>` (or `SUCCESS\|CODE_SENT` unknown) * `ERROR\|RESET_FAILED` |
| `cobol/src/auth_core.cob` | `RESET_PASSWORD` | email, code, new password | consume code, set PBKDF2 hash, bump `token_version` (revoke sessions), audit; **attempt-capped** (burned after 5 wrong guesses) | `SUCCESS\|PASSWORD_RESET` * `ERROR\|INVALID_CODE` * `ERROR\|WEAK_PASSWORD` * `ERROR\|RESET_FAILED` |
| `cobol/src/auth_core.cob` | `CHANGE_PASSWORD` | email, current, new, actor (self) | verify current password, set new hash, bump `token_version`, audit | `SUCCESS\|PASSWORD_CHANGED` * `ERROR\|INVALID_CREDENTIALS` * `ERROR\|WEAK_PASSWORD` * `ERROR\|FORBIDDEN` * `ERROR\|PASSWORD_CHANGE_FAILED` |
| `cobol/src/auth_core.cob` | `CHECK_ROLE` | email, role, actor (self-or-admin) | does the user hold the role | `SUCCESS\|ROLE_OK` * `ERROR\|ROLE_DENIED` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|FORBIDDEN` |
| `cobol/src/auth_core.cob` | `CHANGE_ROLE` | target, role, actor(actor must be SUPER_ADMIN) | transactional update; **refuses to demote the last active SUPER_ADMIN** (`ERROR\|LAST_ADMIN`); audit row **attributed to the actor** (entity_id = target) | `SUCCESS\|ROLE_CHANGED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_ROLE` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|LAST_ADMIN` * `ERROR\|ROLE_CHANGE_FAILED` |
| `cobol/src/auth_core.cob` | `ARCHIVE_AUDIT` | retention days, actor (SUPER_ADMIN) | move audit rows older than the window to `audit_trail_archive` | `SUCCESS\|ARCHIVED` * `ERROR\|FORBIDDEN` * `ERROR\|AUDIT_ARCHIVE_FAILED` |
| `cobol/src/auth_core.cob` | `STORE_SESSION` | jti, email, days | record a refresh-token session | `SUCCESS\|SESSION_STORED` * `ERROR\|SESSION_STORE_FAILED` |
| `cobol/src/auth_core.cob` | `REVOKE_SESSION` | jti | remove one refresh session (per-device logout) | `SUCCESS\|SESSION_REVOKED` * `ERROR\|SESSION_REVOKE_FAILED` |
| `cobol/src/auth_core.cob` | `LIST_SESSIONS` | email, actor (self-or-admin), sid | active (unrevoked, unexpired) refresh sessions as `jti:created:expires:user-agent:ip:current;...` (`current` marks the caller's own family) | `SUCCESS\|SESSIONS\|...` * `ERROR\|FORBIDDEN` * `ERROR\|SESSION_LIST_FAILED` |
| `cobol/src/auth_core.cob` | `REVOKE_USER_SESSION` | email, actor, session id | revoke one session that belongs to the account (self, or an admin not lower-ranked) | `SUCCESS\|SESSION_REVOKED` * `ERROR\|SESSION_NOT_FOUND` * `ERROR\|FORBIDDEN` * `ERROR\|SESSION_REVOKE_FAILED` |
| `cobol/src/auth_core.cob` | `REVOKE_ALL_SESSIONS` | email, actor (self, or an admin not lower-ranked) | bump `token_version` **and** revoke every refresh session (logout everywhere), audited | `SUCCESS\|SESSIONS_REVOKED` * `ERROR\|FORBIDDEN` * `ERROR\|SESSIONS_REVOKE_FAILED` |
| `cobol/src/auth_core.cob` | `CONSUME_SESSION` | jti | **atomic** rotate: consume (revoke) the session in one conditional update and enforce the family's absolute lifetime / rotation cap; a replay is reuse — kills the family, bumps `token_version` and audits | `SUCCESS\|SESSION_CONSUMED` * `ERROR\|SESSION_REUSED` * `ERROR\|SESSION_NOT_FOUND` * `ERROR\|SESSION_EXPIRED` * `ERROR\|SESSION_FAMILY_EXPIRED` |
| `cobol/src/auth_core.cob` | `GET_TOKEN_VERSION` | email | current access-token version for a user | `SUCCESS\|<ver>` * `ERROR\|ACCOUNT_NOT_FOUND` |
| `cobol/src/auth_core.cob` | `CHECK_TOKEN` | email, version, jti | access token is current and not denylisted | `SUCCESS\|TOKEN_VALID` * `ERROR\|TOKEN_REVOKED` * `ERROR\|ACCOUNT_NOT_FOUND` |
| `cobol/src/auth_core.cob` | `REVOKE_ACCESS_TOKEN` | jti, email, ttl seconds | deny one access token until it would expire | `SUCCESS\|TOKEN_REVOKED` * `ERROR\|TOKEN_REVOKE_FAILED` |
| `cobol/src/auth_core.cob` | `PING` | - | deep health: DB reachability | `SUCCESS\|PONG` * `ERROR\|DB_DOWN` |

The routing contract is that every action dispatched by `cobol/src/main_logic.cob`
is handled by its owning module; `ci.sh` verifies every routed
action has a handler in its owning module.

## 3. Database (`cobol_db`)

Tables in `database/schema.sql` (evolves via `database/migrations/`):
`users` (with `token_version`) * `currencies` * `accounts` * `ledger` *
`verification_logs` * `audit_trail` * `audit_trail_archive` * `pending_transactions` * `pending_transactions_archive` * `transfer_reversals` * `refresh_sessions` (jti + `family` + user-agent/ip) * `refresh_families` (absolute lifetime + `rotations`) * `exchange_rates` * `revoked_access_tokens` * `schema_migrations`
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
| `tests/test_signup_verify.sh` | 27 | signup + verify flow, PBKDF2 hash, neutral duplicate email, audit, expired-log pruning, resend verification |
| `tests/test_roles.sh` | 17 | `CHECK_ROLE` self-or-admin, `CHANGE_ROLE` SUPER_ADMIN gate, `ARCHIVE_AUDIT` |
| `tests/test_user_profile.sh` | 41 | full profile (incl. account-less), rich user record + paged listing with role filter, update profile, email-change (validation + race) |
| `tests/test_account_lifecycle.sh` | 15 | self deactivation, admin status changes, login honours SUSPENDED/CLOSED, side-effect revocation |
| `tests/test_login_lockout.sh` | 14 | 3-fail/15-min lockout on the user row, masked probe (wrong stays uniform, owner told), reset/good-login unlock |
| `tests/test_idempotent_transfer.sh` | 27 | replay-no-op, key reuse conflict, per-sender scoping, unique auto refs, failure retry, archived key runs fresh |
| `tests/test_transfer_validity.sh` | 34 | positive-amount, malformed-amount rejection (core-level), self-transfer, cross-currency (direct + inverse rate + missing rate), target precision, rate snapshot, multi-account sender selection by currency |
| `tests/test_wallet_observability.sh` | 7 | TRANSFER audit context (target:amount:currency, actor), idempotency-intent retention (stale archived, fresh kept) |
| `tests/test_transfer_limits.sh` | 10 | per-transaction cap (boundary + over) and rolling 24h cap, rejected transfers move nothing |
| `tests/test_transfer_reversal.sh` | 21 | admin-only one-time reversal (compensating entries, balances restored), status owner/admin-only, admin sender filter/determinism, ALREADY_REVERSED, insufficient claw-back |
| `tests/test_account_status.sh` | 13 | transfer needs ACTIVE sender/target and enabled currencies; failures move nothing; frozen balance still readable |
| `tests/test_injection.sh` | 9 | auth values escaped (accepted literally); user/wallet still whitelist-only |
| `tests/test_session.sh` | 18 | STORE/CHECK/REVOKE_SESSION, reuse detection, pruning, token-version + per-token revocation |
| `tests/test_sessions_manage.sh` | 19 | list active sessions (user-agent + IP, current session marked), revoke one (owner/admin, own only), revoke-all (version bump + all refresh revoked, audited) |
| `tests/test_token_rotation.sh` | 20 | atomic consume (first wins), replay reuse kills family + bumps version + audits, unknown/expired, family absolute lifetime + rotation cap (`SESSION_FAMILY_EXPIRED` + audit), denylist pruning on store |
| `tests/test_admin_hierarchy.sh` | 12 | role hierarchy: a MANAGER cannot suspend/close/verify a SUPER_ADMIN nor revoke its sessions; equal/higher ranks allowed; self-service unaffected |
| `tests/test_last_admin.sh` | 13 | last-admin protection: cannot demote/suspend/close/unverify or self-deactivate the final active SUPER_ADMIN; allowed once a second super exists |
| `tests/test_prepared.sh` | 15 | signup/login/transfer/reconcile (`SQL_PREPARE_EXEC`), locking read (`SQL_PREPARE_EXEC_LOCK`) and list (`SQL_PREPARE_EXEC_ROWS`) through prepared statements |
| `tests/test_ping.sh` | 3 | deep-health PING reaches the DB; connection settings come from the environment |
| `tests/test_migrate.sh` | 8 | migration runner idempotent; --check detects pending; dead columns/table gone |
| `tests/test_concurrent_transfer.sh` | 4 | opposing concurrent transfers all succeed, money conserved |
| `tests/test_e2e_gateway.sh` | 22 | live-gateway HTTP flow: signup→verify→login→transfer→refresh→metrics→logout; `/wallet/balance` envelope + currency |
| `tests/test_serve_mode.sh` | 12 | long-running `--serve`, file mode unchanged, connection lifecycle (reconnect + transaction) |
| `tests/test_password.sh` | 14 | forgot/reset/change password (code single-use, sessions revoked, owner-only) |
| `tests/test_verify_cap.sh` | 10 | verification attempt cap for SIGNUP, PASSWORD_RESET and EMAIL_CHANGE (below cap, burn at cap, fresh code, single active code) |
| `tests/test_password_kdf.sh` | 8 | PBKDF2 cost configurable + modern default, legacy SHA256 upgrade, rehash-on-login for under-cost PBKDF2, no needless rehash |
| `tests/test_mfa.sh` | 16 | TOTP enrol/confirm/login/disable, MFA required and enforced, owner-only, bad codes rejected |
| `middleware/` (node --test) | 79 | gateway: contract, injection, rate limit (auth + api, shared store), refresh rotation/reuse, access-token revocation (version + per-token), per-device logout, **JWT algorithm pinning**, timeout, line cap, paging cap, uniform envelope, multi-record output, every-endpoint smoke, actor-token guard, anti-enumeration, attempt cap, lockout masking, MFA, session listing/revoke-all, JWT issuer/audience, wallet account status, required idempotency key, transfer limits, transfer status/reversal, inverse FX, account selection, structured profile, rich user listing, neutral email change, profile update, account lifecycle, email-change race, observability (pull + push, pool gauges), idempotency conflict, self-transfer, audit archive, password reset/change, resend verification, security headers/config, mailer, worker pool (pipelined), error mapping |

Shell suites total **489**; with the gateway suite **79** the full run is
**568 assertions**, all green as of this snapshot (plus a second end-to-end HTTP
smoke run in pool mode).

## 5. Gateway surface (`middleware/`)

Held by a bearer JWT (public: `/health`, `/auth/signup`, `/auth/verify`,
`/auth/login`, `/auth/forgot`, `/auth/reset-password`, `/auth/resend`, `/auth/refresh):
`/users`, `/users/:email`, `/wallet/balance`, `/wallet/transfer`
(`Idempotency-Key`), `/profile` (GET/PATCH), `/profile/deactivate`,
`/profile/email/request`,
`/profile/email/confirm`, `/profile/password`, `/admin/user-status`, `/mfa/enroll`, `/mfa/confirm`,
`/mfa/disable`, `/sessions` (GET), `/sessions/revoke`, `/sessions/revoke-all`,
`/admin/role` (GET/POST),
`/admin/reconcile`
(read-only balance/ledger check), `/metrics` (Prometheus counters, bearer),
`/auth/logout` (per-device: removes the presented refresh session and denies the
bearer if sent), `/auth/revoke` (revokes the presented
access token), `/admin/audit/archive` (moves old audit rows to the archive).
Both admin routes (`/admin/role` POST, `/admin/reconcile`) take the actor from
the verified token, never the request body. The per-user reads (`/users/:email`,
`/wallet/balance`, `/profile`) and the role check `GET /admin/role` allow the
owner or an admin; `/users` (list) is
admin-only. Writes are owner-scoped too: a transfer is always sent from the
token's account, and the email-change flow only acts on the token's own email.
Actor/sender identity always comes from the token.
Status mapping: 200 on `SUCCESS`; 400/401/403/404/409/423/429/500/504 by error
code (see `middleware/src/result.js`; session/token failures map to 401 and
internal/bridge failures to 500). Input-line cap 500 bytes; fixed-window
rate limiting per client (`RATE_LIMIT_*` on `/auth/*`, more generous
`API_RATE_LIMIT_*` on the rest; `/health` exempt; counters are shared via Redis
when REDIS_URL is set, and the client IP follows TRUST_PROXY); access token
15m + refresh 7d
(`middleware/.env.example`). Every response carries `X-Request-Id`, and the
server logs one JSON line per request (`event: http_request` with method, route,
status, `durationMs`, `cobolMs`); counters are served at `/metrics` and, when
METRICS_PUSH_URL is set, pushed periodically to a collector.
`helmet` sets standard security headers, and in production the server refuses to
start while JWT_SECRET/REFRESH_SECRET are unset, still the development
defaults, shorter than 32 characters, or **identical to each other**. Access and
refresh tokens are bound to an issuer and audience
(JWT_ISSUER / JWT_AUDIENCE, defaulting to `cobol-banking-core` /
`cobol-banking-api`) and verification rejects tokens that do not match them.
Tokens are signed and verified with **HMAC-SHA256 only** (`algorithms: ['HS256']`
on verify), so a token claiming `alg: none` or another algorithm family is
rejected. Verification codes (`/auth/signup`, `/profile/email/request`) are
delivered out of band (SMTP when configured, otherwise logged without the code
in development) and are never returned in the HTTP response. Access tokens carry
the user's token version, checked on every protected request (`CHECK_TOKEN`);
an admin/status change or a password/email change bumps it, so already-issued
access tokens can be revoked before they expire. A single token can be revoked
per `jti` (`POST /auth/revoke` -> `REVOKE_ACCESS_TOKEN`), and `POST /auth/logout`
is per-device: it removes the presented refresh session and, when the bearer is
also sent, denies that access token — other devices keep working. The denylist
lives in the shared database behind
a `tokenStore` seam (a distributed store can replace it). A user (or an admin)
can list their active refresh sessions (`GET /sessions`), revoke one, or revoke
them all (`POST /sessions/revoke-all` -> `REVOKE_ALL_SESSIONS`, which bumps the
version *and* revokes every refresh session). Responses share one
envelope - success `{ data: [...] }`, failure `{ error, detail? }` - and the
list page size is capped at 100 (`limit` 1..100).

## 6. Governance documents

- `docs/HISTORY.md` - every merged phase, its commits, and date (regenerate with `docs/gen_history.sh`).
- `docs/adr/0001-invocation-model.md`, `docs/adr/0002-auth-db-stack.md`, `docs/adr/0003-idempotent-transfers.md`, `docs/adr/0004-schema-migrations.md`, `docs/adr/0005-cross-currency-transfers.md`, `docs/adr/0006-token-revocation.md`, `docs/adr/0007-distributed-rate-limiting.md`, `docs/adr/0008-metrics-export.md`, `docs/adr/0009-audit-retention.md`, `docs/adr/0010-worker-pool-invocation.md` - decisions.
- `CODING_STANDARDS.md` - review rules.
- `scripts/install-hooks.sh` - installs a pre-commit hook that blocks commits on `main`.

## 7. Known gaps (deliberate, by scale)

- Password KDF is PBKDF2-SHA256 at 600000 iterations (modern guidance), overridable with the PBKDF2_ITERATIONS env var (the test suite runs at 100000). Login rehashes any legacy `SHA256_` hash or PBKDF2 hash below the current cost on a successful password check, and the derived-key comparison is constant-time.
- Login lockout lives on the user row (`failed_logins` / `locked_until`; 3 failures sets a 15-minute block) and is **masked**: a wrong password returns the same `INVALID_CREDENTIALS` whether the account is unknown, unlocked, or locked, so it cannot enumerate or probe lock state; only a correct password reveals `ACCOUNT_LOCKED`. A good login or a password reset clears the counter. A determined attacker can still keep a *known* account locked (the block is time-based); recovery is the emailed password reset.
- MFA is TOTP (RFC 6238, SHA-1 / 6 digits / 30s) against a base32 secret on the user row, enforced at login; the autoprovisioning URI uses the issuer from the MFA_ISSUER env var (default `CobolBank`). There are no backup/recovery codes yet, and TOTP verification allows +/- one 30s step of clock drift.
- Transfers require both accounts to be `ACTIVE` and both currencies enabled (`ACCOUNT_FROZEN`/`ACCOUNT_CLOSED`/`CURRENCY_INACTIVE` otherwise); the amount must be positive; cross-currency credits at the stored `exchange_rates` base->target rate, falling back to the reciprocal of the inverse pair when only that exists (neither direction is `RATE_NOT_FOUND`); debit/credit are rounded to each currency's `prec_val` and the applied rate is **snapshotted** on the CREDIT `ledger` row. `/wallet/balance` returns every account as `iso:balance:status`. The gateway **requires** an `Idempotency-Key` on a transfer; keys are unique per sender (`pending_transactions` UNIQUE `from_email, txn_ref`, plus an auto-increment `id` for deterministic ordering), so two senders may reuse one. A concurrent same-key attempt returns `TRANSFER_IN_PROGRESS` and resolves to a replay on retry. A SUPER_ADMIN can reverse a transfer once (`REVERSE_TRANSFER` posts compensating `ledger` entries and a `transfer_reversals` marker); it only succeeds while the target still holds the credited funds. Transient DB failures (lock wait / deadlock / lost connection) return `DB_BUSY` (503) instead of `DB_ERROR`; idempotency intents are **archived** past a retention window (env PENDING_RETENTION_DAYS, default 30 days, 0 disables), so replay is a bounded guarantee while the history is kept. The core validates the amount format itself (a plain positive decimal with at most two fractional digits), independently of the gateway pattern; numeric working fields are `S9(16)V99` to match `DECIMAL(18,4)` balances (accounting for the `NUMVAL` decimal handling). A multi-account sender or recipient can be pinned by currency (`fromCurrency`/`toCurrency`, transfer p5/p6).
- Email-change requests are **neutral**: requesting a change to an already-registered address returns the same `CODE_SENT` success with no code (nothing delivered and no `EMAIL_CHANGE` code stored), so the action cannot enumerate emails. Email change is owner-only, requires the **current password**, and on confirm **bumps `token_version` and revokes every refresh session** (clean re-login); the old address is notified.
- Account lifecycle: `users.status` is `UNVERIFIED`/`VERIFIED`/`SUSPENDED`/`CLOSED`. The owner can soft-close their account (`DEACTIVATE_ACCOUNT` -> `CLOSED`) and an admin can set any status (`SET_USER_STATUS`). Login refuses `SUSPENDED`/`CLOSED` with `USER_SUSPENDED`/`USER_CLOSED`; deactivation and every status change bump `token_version` and revoke refresh sessions, so existing tokens die immediately.
- **Admin role hierarchy** (USER < MANAGER < SUPER_ADMIN): an actor may not administer an account ranked **above** it. `SET_USER_STATUS`, `REVOKE_USER_SESSION` and `REVOKE_ALL_SESSIONS` refuse when the actor is lower-ranked than the target — so a MANAGER can never suspend/close a SUPER_ADMIN or force-logout its sessions. Equal ranks are allowed (a SUPER_ADMIN may act on a peer for incident response), and self-service is always allowed. FASE B (last-admin protection) builds on this.
- **Last-admin protection**: the system refuses to leave itself without an active (VERIFIED) SUPER_ADMIN. `CHANGE_ROLE` rejects demoting the last one, `SET_USER_STATUS` rejects suspending/closing/unverifying it, and `DEACTIVATE_ACCOUNT` rejects self-closing it — all with `ERROR|LAST_ADMIN` (HTTP 409). Once a second active SUPER_ADMIN exists the change is allowed. Recovery if the admin population is ever lost is out-of-band (a DBA sets `role='SUPER_ADMIN'`); see ADR 0014.
- Profile actions validate their own inputs in COBOL (email shape, date-of-birth format/ranges) as defence-in-depth alongside the gateway patterns; an email-change whose new address is taken between request and confirm is reported as `EMAIL_EXISTS` rather than an opaque failure.
- Refresh **rotation is atomic** (`CONSUME_SESSION`: a single conditional revoke; concurrent callers cannot both win). A replay of a consumed token is reuse — the gateway's `/auth/refresh` rejects it, the whole family is revoked, the user's `token_version` is bumped (so previously issued access tokens die immediately) and a `SESSION_REUSED` audit row is written.
- **Logout is per-device**: `/auth/logout` removes only the presented refresh session (so replaying a logged-out token is a plain `SESSION_NOT_FOUND`, not a reuse that would nuke every device) and, when the bearer is also presented, adds that access token's `jti` to the denylist. Other devices are unaffected; `POST /sessions/revoke-all` remains the logout-everywhere path.
- **JWT is algorithm-pinned**: every `jwt.verify` passes `algorithms: ['HS256']` and every `jwt.sign` sets `algorithm: 'HS256'`, so algorithm-confusion tokens (`alg: none`, HS384, ...) are rejected. In production `assertSecureConfig` additionally refuses secrets that are missing, the development defaults, shorter than 32 characters, or identical between access and refresh.
- **Refresh families have an absolute lifetime and a rotation cap**: each login starts a family (`refresh_families`); `CONSUME_SESSION` refuses — and revokes the family with `SESSION_FAMILY_EXPIRED` — once it is older than `REFRESH_ABSOLUTE_TTL_DAYS` (default 30) or has rotated more than `REFRESH_MAX_ROTATIONS` times (default 100), forcing a fresh login even though the current refresh token is still within its own expiry. Set either to 0 to disable that check. The check **fails closed** if the family state cannot be read.
- **Security events are audited**: reuse (`SESSION_REUSED`) and a forced family expiry (`SESSION_FAMILY_EXPIRED`) both write an `audit_trail` row with `status='FAILED'`. The access-token denylist is pruned of expired rows whenever a session is stored (`STORE_SESSION` housekeeping, alongside expired `refresh_sessions`), so it does not grow without bound.
- **Sessions carry metadata and the current device is marked**: `STORE_SESSION` records the client **user-agent and IP** on each refresh session, and `GET /sessions` returns them. The access token now carries a `sid` claim equal to its refresh-session `family`, so the list marks the caller's own session with `current`.
- Optional transfer caps are read from the environment and **off by default** (0): TRANSFER_MAX_PER_TXN caps one debit, TRANSFER_DAILY_LIMIT caps the rolling 24h debit total per account (from the `ledger`); the values are whole units of the sender's currency.
- Email change updates `users.email`; related FKs (`refresh_sessions`, `pending_transactions`) cascade on update (migrations 0003 and 0004, which repairs a 0001/0003 ordering regression), so a logged-in user with a transfer intent can still change their email.
- Prepared statements are used for the parameterized queries in `user_core`, `wallet_core` and most of `auth_core`; the remaining `auth_core` statements (login/lockout, signup/verify, audit) embed `mysql_real_escape_string`-escaped values, which the whitelist validator plus escaping keep safe. The locking `SELECT ... FOR UPDATE` uses `SQL_PREPARE_EXEC_LOCK` (bound params, no row fetch) because reading its result via `mysql_stmt_store_result` makes MariaDB raise `ER_CHECKREAD` (1020) under contention. Prepared SQL is bounded at 1023 chars (`WS-PREP-SQL` `PIC X(1024)`).
- `audit_trail` records `REQUEST_SIGNUP` (SUCCESS), `VERIFY_EMAIL` (SUCCESS, and FAILED for a bad/expired/reused code when the email belongs to a user; unattributable attempts are skipped), `AUTH_LOGIN_FAILED`, `TRANSFER`, `EMAIL_CHANGE`, and `CHANGE_ROLE`. Refresh tokens are single-use and rotate within a `family`; presenting an already-revoked token is treated as reuse and revokes the whole family (all sessions for that login), so a stolen token cannot be replayed.
- Expired `refresh_sessions` and `verification_logs` are pruned opportunistically (on session store and on signup). `audit_trail` is append-only but bounded: `ARCHIVE_AUDIT` moves rows past a retention window into the immutable `audit_trail_archive`.
- Results are written as 500-char records and reassembled by the gateway; the buffers are 16 KB, so extremely large lists still have an upper bound. Invocation defaults to **process-per-request** (file mode); serve mode + keep-alive connection + a **gateway worker pool** are implemented and enabled with COBOL_POOL_SIZE (ADR-0010 phases 1-3).
