# Bridge (libmysqlclient) replaces the ODBC / EXEC SQL auth stack

Status: accepted
Date: 2026-10-10
Phase: 3 (decision) — unblocks reimplementing the auth-identity actions; see ADR-0001 for the invocation model.

## Context

`cobol/src/auth_identity.cob` implements registration, verification, roles and login
using **embedded SQL** (`EXEC SQL … END-EXEC`) against DSN `COBOL_MYSQL`, and expects an
ODBC build (`cobc … -lodbc32`, per `build.bat`). In this environment that path cannot
run:

- **GnuCOBOL 3.2.0 has no bundled `EXEC SQL` preprocessor**, so plain `cobc` cannot
  compile the embedded-SQL source.
- **No ODBC driver is installed** (`odbcinst` absent).
- The shipped, tested binary already talks to MySQL through `cobol/src/sql_bridge.c`
  (libmysqlclient) over the `input.txt` / `output.txt` file contract, and now owns
  transactions (`SQL_BEGIN` / `SQL_COMMIT` / `SQL_ROLLBACK`).

So the repo carries two DB stacks and two I/O contracts, only one of which is live.

## Decision

1. The **bridge stack is the single integration path**: COBOL actions talk to MySQL via
   `sql_bridge.c` and are invoked through the file contract (`input.txt` / `output.txt`).
2. The **ODBC / `EXEC SQL` path is retired.** `cobol/src/auth_identity.cob` is dead code
   (uncompilable here, unreachable from `main_logic`) and will be **deleted once its
   relevant actions are reimplemented on the bridge** — not before, so nothing is lost
   mid-migration.
3. Reusable, dependency-free logic is kept: `cobol/c_lib/hash_lib.c` (`hash_password`,
   `generate_random_code`) moves over as-is.
4. Relevant auth actions to port onto the bridge: `REQUEST_SIGNUP`, `VERIFY_EMAIL`,
   `CHECK_ROLE`, `CHANGE_ROLE`, `AUTH_LOGIN` (see `SPEC-auth-identity.md`).

## Consequences

- Migration is incremental per action; `auth_identity.cob` stays in the tree (marked dead)
  until the last required action is ported, then is removed together with the `build.bat`
  ODBC target.
- New auth actions must join the routing contract in `AGENTS.md` and be tested like the
  wallet actions.
- `cobol/src/precompile_sql.sh` (the sed-based `EXEC SQL` → `CALL "SQL_EXECUTE"` shim)
  becomes redundant with this decision; remove it when `auth_identity.cob` is deleted.
- One DB credential source (`sql_bridge.c`) and one I/O contract remain.
