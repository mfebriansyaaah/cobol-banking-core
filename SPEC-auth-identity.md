# Spec: auth-identity

Status: **migrated** — every required action runs on the bridge (`cobol/src/auth_core.cob`); the legacy ODBC stack has been retired (see `docs/adr/0002-auth-db-stack.md`).
Last verified against code: 2026-10-10

## Objective (unchanged)

Strict identity and authentication: registration, email verification, secure login, so no unverified user can transact.

## As-Built (live, routed by `main_logic`)

- **Source:** `cobol/src/auth_core.cob` (program id `auth_core`), compiled by `build.sh`, DB via `cobol/src/sql_bridge.c`.

| Action | Params | Behavior today | Outputs |
|---|---|---|---|
| `AUTH_LOGIN` | `p1=email`, `p2=password` | reject if 3 failed attempts in 15 min (`ACCOUNT_LOCKED`, row via `audit_trail`); else verify password + status `VERIFIED`; failed attempts are recorded | `SUCCESS\|LOGIN_OK` · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|INVALID_CREDENTIALS` · `ERROR\|UNVERIFIED` · `ERROR\|ACCOUNT_LOCKED` |
| `REQUEST_SIGNUP` | `p1=email`, `p2=password`, `p3=full_name`, `p4=dob` | enforce 8-char password + unique email; insert user `UNVERIFIED` + a secure 6-digit code in `verification_logs` (24h expiry) inside one transaction; return the code | `SUCCESS\|USER_CREATED\|<code>` · `ERROR\|WEAK_PASSWORD` · `ERROR\|EMAIL_EXISTS` · `ERROR\|SIGNUP_FAILED` |
| `VERIFY_EMAIL` | `p1=email`, `p2=code` | match an unused, unexpired `SIGNUP` code and flip the user to `VERIFIED`, all in one transaction | `SUCCESS\|EMAIL_VERIFIED` · `ERROR\|INVALID_CODE` · `ERROR\|VERIFY_FAILED` |
| `CHECK_ROLE` | `p1=email`, `p2=role` | report whether the user holds the given role | `SUCCESS\|ROLE_OK` · `ERROR\|ROLE_DENIED` · `ERROR\|ACCOUNT_NOT_FOUND` |
| `CHANGE_ROLE` | `p1=target email`, `p2=new role`, `p3=actor email` | only a `SUPER_ADMIN` actor may change a role; validates role name and target existence; update inside one transaction | `SUCCESS\|ROLE_CHANGED` · `ERROR\|FORBIDDEN` · `ERROR\|INVALID_ROLE` · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|ROLE_CHANGE_FAILED` |

Password hashing uses a **slow KDF**: PBKDF2-HMAC-SHA256 (100,000 iterations, 16-byte random salt) in `cobol/c_lib/hash_lib.c`, stored as `PBKDF2$<iters>$<salt>$<key>`. Login verifies in C (`verify_password`) and still accepts a legacy `SHA256_…` hash for accounts created before the switch. `hash_lib.c` is Linux-portable and linked by `build.sh` (also provides `generate_random_code`).

### Tests

`tests/test_auth_login.sh`, `tests/test_signup_verify.sh`, `tests/test_roles.sh`. Wired into `ci.sh`.

### Retired

The legacy ODBC stack — the embedded-SQL auth program, its Windows ODBC build script, and the sed-based `EXEC SQL` shim — has been removed (ADR-0002). There is now a single DB stack (`sql_bridge.c`, libmysqlclient) and a single I/O contract (`input.txt` / `output.txt`).

## Deep health

`PING` runs a trivial query and reports `SUCCESS|PONG` / `ERROR|DB_DOWN`, used by the gateway `/health`.

## Injection safety

Most auth queries use **prepared statements** (bridge `SQL_PREPARE_EXEC`, bound parameters): signup insert, login status + failed-login audit, `GET-USER-ID`, `VERIFY_EMAIL` (log check, updates, audit), `CHECK_ROLE`/`CHANGE_ROLE`, and session `REVOKE`/`CONSUME`. Remaining queries (password_hash lookup, weak-password check, email-exists, verification_logs insert, lockout count, `STORE_SESSION`) escape values via `SQL_ESCAPE`; both are safe. Quotes/backslash/semicolon are accepted as literals; only the input-line format characters are refused. `user_core`/`wallet_core` remain whitelist-only (prepared migration pending).

## Session support (refresh tokens)

`auth_core` also owns the refresh-token session store used by the gateway: `STORE_SESSION` (jti, email, days), `REVOKE_SESSION` (jti), and `CONSUME_SESSION` (jti -> atomically consume for rotation), backed by the `refresh_sessions` table.

The gateway's `/auth/refresh` uses **`CONSUME_SESSION`**: a single conditional `UPDATE ... WHERE jti = ? AND revoked = 0 AND expires_at > NOW()`, so only one concurrent caller can win the rotation. A replay of a consumed token is **reuse**: the whole `family` is revoked, the user's `token_version` is bumped (killing every previously issued access token), and a `SESSION_REUSED` audit row is written. `REVOKE_SESSION` backs per-device logout: it **deletes** the session row, so replaying a logged-out token is a plain `SESSION_NOT_FOUND` rather than a reuse that would revoke the family and every device.

Rotation is also bounded per family. `refresh_families` tracks each family's `created_at` and `rotations`; after a successful consume `CONSUME_SESSION` refuses — and revokes the family with `SESSION_FAMILY_EXPIRED` — once the family is older than `REFRESH_ABSOLUTE_TTL_DAYS` (default 30) or has rotated more than `REFRESH_MAX_ROTATIONS` times (default 100), forcing a fresh login. Either limit set to 0 disables it; the check fails closed if the family state cannot be read. Both `SESSION_REUSED` and `SESSION_FAMILY_EXPIRED` are recorded in `audit_trail` as security events. Storing a session also prunes expired rows from the access-token denylist (`revoked_access_tokens`) so it stays bounded.

## Not yet done

- Exit-code contract from the original spec (1 Not Found, 2 DB Error, 4 Invalid Arg) is not implemented; actions signal through the `ERROR|…` output line instead.
- `audit_trail` records failed logins (lockout), `REQUEST_SIGNUP`, `VERIFY_EMAIL`, `CHANGE_ROLE`, `TRANSFER`, and `EMAIL_CHANGE`.

## Done since first cut

- **Account lockout**: `AUTH_LOGIN` counts failed attempts in `audit_trail` and locks after 3 failures within 15 minutes (`ERROR|ACCOUNT_LOCKED`), even for a correct password. Tested by `tests/test_login_lockout.sh`.

## Code style (enforced today)

- Action names must agree between `cobol/src/main_logic.cob` and the owning module (routing contract in `AGENTS.md`).
- Output pipe-delimited, one line; no `GOBACK` in `PERFORM`ed paragraphs (see `CODING_STANDARDS.md`).

## Open questions

- Should the legacy `SHA256_…` fallback be retired once every account has been rehashed to PBKDF2?
