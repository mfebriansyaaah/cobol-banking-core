# Bridge (libmysqlclient) replaces the ODBC / EXEC SQL auth stack

Status: accepted
Date: 2026-10-10
Phase: 3 (decision) — unblocks reimplementing the auth-identity actions; see ADR-0001 for the invocation model.

## Context

The legacy auth program (embedded-SQL, ODBC) implemented registration, verification,
roles and login using `EXEC SQL … END-EXEC` statements against DSN `COBOL_MYSQL`, and
expected an ODBC build (`cobc … -lodbc32`, per the old Windows build script). In this
environment that path cannot run:

- **GnuCOBOL 3.2.0 has no bundled `EXEC SQL` preprocessor**, so plain `cobc` cannot
  compile the embedded-SQL source.
- **No ODBC driver is installed** (`odbcinst` absent).
- The shipped, tested binary already talks to MySQL through `cobol/src/sql_bridge.c`
  (libmysqlclient) over the `input.txt` / `output.txt` file contract, and now owns
  transactions (`SQL_BEGIN` / `SQL_COMMIT` / `SQL_ROLLBACK`).

So the repo carries two DB stacks and two I/O contracts, only one of which is live.

## Decision

1. The **bridge stack is the single integration path**: COBOL actions talk to MySQL via
   `cobol/src/sql_bridge.c` and are invoked through the file contract (`input.txt` / `output.txt`).
2. The **ODBC / `EXEC SQL` path is retired.** That source (embedded-SQL auth program)
   was dead code (uncompilable here, unreachable from `main_logic`) and has since been
   **deleted** together with the Windows ODBC build script and the `EXEC SQL` shim,
   after every required action was reimplemented on the bridge.
3. Reusable, dependency-free logic is kept: `cobol/c_lib/hash_lib.c` (`hash_password`,
   `generate_random_code`) moves over as-is.
4. Relevant auth actions to port onto the bridge: `REQUEST_SIGNUP`, `VERIFY_EMAIL`,
   `CHECK_ROLE`, `CHANGE_ROLE`, `AUTH_LOGIN` (see `SPEC-auth-identity.md`).

## Consequences

- Migration was incremental per action; the legacy program stayed in the tree (marked
  dead) until the last required action was ported, then was removed together with the
  old Windows ODBC build target.
- New auth actions must join the routing contract in `AGENTS.md` and be tested like the
  wallet actions.
- The sed-based `EXEC SQL` → `CALL "SQL_EXECUTE"` shim became redundant with this
  decision and was removed along with the legacy program.
- One DB credential source (`sql_bridge.c`) and one I/O contract remain.
