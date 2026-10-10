# Spec: auth-identity

Status: **built in source, not wired** — `auth_identity.cob` implements the logic but is not compiled into the running binary and not reachable through `main_logic`.
Last verified against code: 2026-10-10

## Objective (unchanged)

Strict identity and authentication: registration, email verification, secure login, so no unverified user can transact.

## As-Built (what exists today)

- **Source:** `cobol/src/auth_identity.cob` (program id `AUTH_IDENTITY`).
- **DB access:** embedded SQL (`EXEC SQL INCLUDE SQLCA`, `EXEC SQL … END-EXEC`) targeting DSN `COBOL_MYSQL` — i.e. the **ODBC path**, configured by `cobol/config/odbc.ini`.
- **Invocation model:** command-line arguments via `LINKAGE` (`LS-ARG-COUNT`, `LS-ARG-VALUE`), exited through `STOP RUN WS-EXIT-CODE` (exit codes: 0 success, 1 not found, 2 DB error, 4 invalid arg).
- **Hash library:** `cobol/c_lib/hash_lib.c` (SHA-256 + 6-digit RNG) via `CALL "generate_random_code"` / hashing call.
- **Build status:** **not** in `build.sh`; `build.bat` (Windows) still targets `cobol/bin/auth_identity.exe` with `-lodbc32`, but that is a separate, older build path. `main_logic.cob` never calls `AUTH_IDENTITY`.

### Actions actually implemented

`TEST_CONN`, `TEST_HASH`, `REQUEST_SIGNUP`, `VERIFY_EMAIL`, `CHECK_ROLE`, `CHANGE_ROLE`, `CHECK_BALANCE`, `DETECT_FRAUD`, `CHECK_LIMITS`, `CALC_INTEREST`, `ACCRUE_INTEREST`, `PAY_INTEREST`, `SEND_NOTIF`, `GET_NOTIFS`, `CHECK_KYC`, `UPGRADE_KYC`, `UPDATE_SCORE`, `TRANSFER`, `AUTH_LOGIN`.

Notable: `REQUEST_SIGNUP`, `VERIFY_EMAIL`, `CHECK_ROLE`, `CHANGE_ROLE`, `AUTH_LOGIN`, and an atomic `TRANSFER` (autocommit off, ledger inserts, commit/rollback) are present here.

## To add / to wire

Direction decided in `docs/adr/0002-auth-db-stack.md`: the ODBC/`EXEC SQL` path is retired; these actions will be reimplemented on the bridge (`sql_bridge.c` + `input.txt`/`output.txt`) and `auth_identity.cob` deleted once migration completes.

- [ ] **Reimplement on the bridge**: `REQUEST_SIGNUP`, `VERIFY_EMAIL`, `CHECK_ROLE`, `CHANGE_ROLE`, `AUTH_LOGIN`, reusing `cobol/c_lib/hash_lib.c`.
- [ ] **Retire** `auth_identity.cob` and `build.bat`'s ODBC target once every required action is ported.
- [ ] **Complete the exit-code contract** (last unchecked item in the original spec): 1 Not Found, 2 DB Error, 4 Invalid Arg on every path.
- [ ] `verification_logs` / `audit_trail` usage: tables exist in `database/schema.sql`; confirm the code paths that write them.

## Code style (enforced today)

- Action names must agree across `main_logic.cob`, `user_core.cob`, `wallet_core.cob` (routing contract in `AGENTS.md`); if this module joins the binary, it joins that contract.
- Output pipe-delimited, one line; no `GOBACK` in `PERFORM`ed paragraphs (see `CODING_STANDARDS.md`).

## Open questions

- ~~Keep ODBC, or fold onto the bridge?~~ **Resolved** — bridge; see `docs/adr/0002-auth-db-stack.md`.
- Does the hashing algorithm (`hash_lib.c`) meet the production requirement (bcrypt/Argon2), or is SHA-256 a placeholder?
