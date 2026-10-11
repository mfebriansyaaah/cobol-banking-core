# Spec: auth-identity

Status: **migration started** — `AUTH_LOGIN` is implemented on the bridge (see `docs/adr/0002-auth-db-stack.md`); the legacy `auth_identity.cob` (ODBC) remains dead code until the rest of the actions are ported.
Last verified against code: 2026-10-10

## Objective (unchanged)

Strict identity and authentication: registration, email verification, secure login, so no unverified user can transact.

## As-Built (what exists today)

### On the bridge (live, routed by `main_logic`)

- **Source:** `cobol/src/auth_core.cob` (program id `auth_core`), compiled by `build.sh`, DB via `sql_bridge.c`.

| Action | Params | Behavior today | Outputs |
|---|---|---|---|
| `AUTH_LOGIN` | `p1=email`, `p2=password` | look up status by email; verify password via `password_hash = CONCAT('SHA256_', SHA2(pwd,256))`; require status `VERIFIED` | `SUCCESS\|LOGIN_OK` · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|INVALID_CREDENTIALS` · `ERROR\|UNVERIFIED` |
| `REQUEST_SIGNUP` | `p1=email`, `p2=password`, `p3=full_name`, `p4=dob` | enforce 8-char password + unique email; insert user `UNVERIFIED` + a secure 6-digit code in `verification_logs` (24h expiry) inside one transaction; return the code | `SUCCESS\|USER_CREATED\|<code>` · `ERROR\|WEAK_PASSWORD` · `ERROR\|EMAIL_EXISTS` · `ERROR\|SIGNUP_FAILED` |
| `VERIFY_EMAIL` | `p1=email`, `p2=code` | match an unused, unexpired `SIGNUP` code and flip the user to `VERIFIED`, all in one transaction | `SUCCESS\|EMAIL_VERIFIED` · `ERROR\|INVALID_CODE` · `ERROR\|VERIFY_FAILED` |
| `CHECK_ROLE` | `p1=email`, `p2=role` | report whether the user holds the given role | `SUCCESS\|ROLE_OK` · `ERROR\|ROLE_DENIED` · `ERROR\|ACCOUNT_NOT_FOUND` |
| `CHANGE_ROLE` | `p1=target email`, `p2=new role`, `p3=actor email` | only a `SUPER_ADMIN` actor may change a role; validates role name and target existence; update inside one transaction | `SUCCESS\|ROLE_CHANGED` · `ERROR\|FORBIDDEN` · `ERROR\|INVALID_ROLE` · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|ROLE_CHANGE_FAILED` |

Password hashing matches `hash_password` in `cobol/c_lib/hash_lib.c` (`"SHA256_"` + sha256 hex). `hash_lib.c` is **now Linux-portable** (Windows headers guarded) and linked by `build.sh` for `generate_random_code`; password hashing is done server-side via MySQL `SHA2()`.

### Tests

`tests/test_auth_login.sh`, `tests/test_signup_verify.sh`, `tests/test_roles.sh`. Wired into `ci.sh`.

### Legacy (dead code, to be retired)

`cobol/src/auth_identity.cob` (program id `AUTH_IDENTITY`) implements 19 actions with embedded SQL/ODBC (`EXEC SQL … END-EXEC`), including `REQUEST_SIGNUP`, `VERIFY_EMAIL`, `CHECK_ROLE`, `CHANGE_ROLE`, `AUTH_LOGIN`, and atomic transfer. Not compiled by `build.sh`, not routed by `main_logic`.

## To add / to wire

Direction decided in `docs/adr/0002-auth-db-stack.md`: the ODBC/`EXEC SQL` path is retired; these actions will be reimplemented on the bridge (`sql_bridge.c` + `input.txt`/`output.txt`) and `auth_identity.cob` deleted once migration completes.

- [x] `AUTH_LOGIN` on the bridge (`cobol/src/auth_core.cob`), tested by `tests/test_auth_login.sh`.
- [x] `REQUEST_SIGNUP` on the bridge (Linux-portable `hash_lib.c`, secure 6-digit code), tested by `tests/test_signup_verify.sh`.
- [x] `VERIFY_EMAIL` on the bridge, tested by `tests/test_signup_verify.sh`.
- [x] `CHECK_ROLE`, `CHANGE_ROLE` on the bridge, tested by `tests/test_roles.sh`.
- [ ] **Retire** `auth_identity.cob` and `build.bat`'s ODBC target once every required action is ported; remove `cobol/src/precompile_sql.sh`.
- [ ] Account lockout (3+ failures/15m) for `AUTH_LOGIN`.
- [ ] Password hashing uses plain SHA-256 server-side; a slow KDF (bcrypt/Argon2) is still outstanding for production.
- [ ] **Complete the exit-code contract** (last unchecked item in the original spec): 1 Not Found, 2 DB Error, 4 Invalid Arg on every path.
- [ ] `verification_logs` / `audit_trail` usage: tables exist in `database/schema.sql`; confirm the code paths that write them.

## Code style (enforced today)

- Action names must agree across `main_logic.cob`, `user_core.cob`, `wallet_core.cob` (routing contract in `AGENTS.md`); if this module joins the binary, it joins that contract.
- Output pipe-delimited, one line; no `GOBACK` in `PERFORM`ed paragraphs (see `CODING_STANDARDS.md`).

## Open questions

- ~~Keep ODBC, or fold onto the bridge?~~ **Resolved** — bridge; see `docs/adr/0002-auth-db-stack.md`.
- Does the hashing algorithm (`hash_lib.c`) meet the production requirement (bcrypt/Argon2), or is SHA-256 a placeholder?
