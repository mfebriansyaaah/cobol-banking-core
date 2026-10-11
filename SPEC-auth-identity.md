# Spec: auth-identity

Status: **migrated** — every required action runs on the bridge (`cobol/src/auth_core.cob`); the legacy ODBC stack has been retired (see `docs/adr/0002-auth-db-stack.md`).
Last verified against code: 2026-10-10

## Objective (unchanged)

Strict identity and authentication: registration, email verification, secure login, so no unverified user can transact.

## As-Built (live, routed by `main_logic`)

- **Source:** `cobol/src/auth_core.cob` (program id `auth_core`), compiled by `build.sh`, DB via `cobol/src/sql_bridge.c`.

| Action | Params | Behavior today | Outputs |
|---|---|---|---|
| `AUTH_LOGIN` | `p1=email`, `p2=password` | look up status by email; verify password via `password_hash = CONCAT('SHA256_', SHA2(pwd,256))`; require status `VERIFIED` | `SUCCESS\|LOGIN_OK` · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|INVALID_CREDENTIALS` · `ERROR\|UNVERIFIED` |
| `REQUEST_SIGNUP` | `p1=email`, `p2=password`, `p3=full_name`, `p4=dob` | enforce 8-char password + unique email; insert user `UNVERIFIED` + a secure 6-digit code in `verification_logs` (24h expiry) inside one transaction; return the code | `SUCCESS\|USER_CREATED\|<code>` · `ERROR\|WEAK_PASSWORD` · `ERROR\|EMAIL_EXISTS` · `ERROR\|SIGNUP_FAILED` |
| `VERIFY_EMAIL` | `p1=email`, `p2=code` | match an unused, unexpired `SIGNUP` code and flip the user to `VERIFIED`, all in one transaction | `SUCCESS\|EMAIL_VERIFIED` · `ERROR\|INVALID_CODE` · `ERROR\|VERIFY_FAILED` |
| `CHECK_ROLE` | `p1=email`, `p2=role` | report whether the user holds the given role | `SUCCESS\|ROLE_OK` · `ERROR\|ROLE_DENIED` · `ERROR\|ACCOUNT_NOT_FOUND` |
| `CHANGE_ROLE` | `p1=target email`, `p2=new role`, `p3=actor email` | only a `SUPER_ADMIN` actor may change a role; validates role name and target existence; update inside one transaction | `SUCCESS\|ROLE_CHANGED` · `ERROR\|FORBIDDEN` · `ERROR\|INVALID_ROLE` · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|ROLE_CHANGE_FAILED` |

Password hashing matches `hash_password` in `cobol/c_lib/hash_lib.c` (`"SHA256_"` + sha256 hex). That library is Linux-portable (Windows headers guarded) and linked by `build.sh` for `generate_random_code`; password hashing is done server-side via MySQL `SHA2()`.

### Tests

`tests/test_auth_login.sh`, `tests/test_signup_verify.sh`, `tests/test_roles.sh`. Wired into `ci.sh`.

### Retired

The legacy ODBC stack — the embedded-SQL auth program, its Windows ODBC build script, and the sed-based `EXEC SQL` shim — has been removed (ADR-0002). There is now a single DB stack (`sql_bridge.c`, libmysqlclient) and a single I/O contract (`input.txt` / `output.txt`).

## Not yet done

- Account lockout (3+ failures/15m) for `AUTH_LOGIN`.
- Password hashing is plain SHA-256; a slow KDF (bcrypt/Argon2) is still outstanding for production.
- Exit-code contract from the original spec (1 Not Found, 2 DB Error, 4 Invalid Arg) is not implemented; actions signal through the `ERROR|…` output line instead.
- `audit_trail` writes are not wired (the table exists in `database/schema.sql`).

## Code style (enforced today)

- Action names must agree between `cobol/src/main_logic.cob` and the owning module (routing contract in `AGENTS.md`).
- Output pipe-delimited, one line; no `GOBACK` in `PERFORM`ed paragraphs (see `CODING_STANDARDS.md`).

## Open questions

- Does the hashing algorithm satisfy the production requirement (bcrypt/Argon2), or is SHA-256 a placeholder?
