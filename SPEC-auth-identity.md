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
| `AUTH_LOGIN` | `p1=email`, `p2=password` | look up status by email; verify password via `password_hash = CONCAT('SHA256_', SHA2(RTRIM(pwd),256))`; require status `VERIFIED` | `SUCCESS\|LOGIN_OK` · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|INVALID_CREDENTIALS` · `ERROR\|UNVERIFIED` |

Password hashing matches `hash_password` in `cobol/c_lib/hash_lib.c` (`"SHA256_"` + sha256 hex). `hash_lib.c` itself is **Windows-only** (unguarded `windows.h`), so the bridge reproduces the hash server-side via MySQL `SHA2()`; porting `hash_lib.c` to Linux is a later concern for code generation at signup.

### Legacy (dead code, to be retired)

`cobol/src/auth_identity.cob` (program id `AUTH_IDENTITY`) implements 19 actions with embedded SQL/ODBC (`EXEC SQL … END-EXEC`), including `REQUEST_SIGNUP`, `VERIFY_EMAIL`, `CHECK_ROLE`, `CHANGE_ROLE`, `AUTH_LOGIN`, and atomic transfer. Not compiled by `build.sh`, not routed by `main_logic`.

## To add / to wire

Direction decided in `docs/adr/0002-auth-db-stack.md`: the ODBC/`EXEC SQL` path is retired; these actions will be reimplemented on the bridge (`sql_bridge.c` + `input.txt`/`output.txt`) and `auth_identity.cob` deleted once migration completes.

- [x] `AUTH_LOGIN` on the bridge (`cobol/src/auth_core.cob`), tested by `tests/test_auth_login.sh`.
- [ ] `REQUEST_SIGNUP` on the bridge (needs Linux-portable code generation: 6-digit code + hash).
- [ ] `VERIFY_EMAIL` on the bridge.
- [ ] `CHECK_ROLE`, `CHANGE_ROLE` on the bridge.
- [ ] **Retire** `auth_identity.cob` and `build.bat`'s ODBC target once every required action is ported; remove `cobol/src/precompile_sql.sh`.
- [ ] Account lockout (3+ failures/15m) for `AUTH_LOGIN`.
- [ ] **Complete the exit-code contract** (last unchecked item in the original spec): 1 Not Found, 2 DB Error, 4 Invalid Arg on every path.
- [ ] `verification_logs` / `audit_trail` usage: tables exist in `database/schema.sql`; confirm the code paths that write them.

## Code style (enforced today)

- Action names must agree across `main_logic.cob`, `user_core.cob`, `wallet_core.cob` (routing contract in `AGENTS.md`); if this module joins the binary, it joins that contract.
- Output pipe-delimited, one line; no `GOBACK` in `PERFORM`ed paragraphs (see `CODING_STANDARDS.md`).

## Open questions

- ~~Keep ODBC, or fold onto the bridge?~~ **Resolved** — bridge; see `docs/adr/0002-auth-db-stack.md`.
- Does the hashing algorithm (`hash_lib.c`) meet the production requirement (bcrypt/Argon2), or is SHA-256 a placeholder?
