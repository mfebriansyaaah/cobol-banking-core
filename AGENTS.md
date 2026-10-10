# AGENTS.md

## Navigation

- `ci.sh` — the repo's one-shot check command: static COBOL checks, build, both test suites. Run it before committing; it must exit 0 with `ALL GREEN`.
- `build.sh` — compiles all COBOL modules + `sql_bridge.c` into a single binary (`cobol/bin/main_logic`). Edit this file, never an ad-hoc `cobc` invocation.
- `tests/test_suite.sh`, `tests/test_atomic_txn.sh` — functional and atomic-transaction suites. Both need the MySQL database `cobol_db` seeded via `database/schema.sql` + `database/seed_test_data.sql`; each suite resets DB state itself.

## Routing contract (edit together)

Action names (`CHECK_BALANCE`, `TRANSFER`, `GET_USER`, `LIST_USERS`) are matched in **three files at once**: `cobol/src/main_logic.cob` (routing), `cobol/src/user_core.cob`, `cobol/src/wallet_core.cob`. Adding or renaming an action requires editing all three; review must check all three agree.

## I/O architecture

The binary reads one pipe-delimited line from `input.txt` and writes exactly one result line to `output.txt`. Args format: `ACTION|param1|param2|param3|param4`.
