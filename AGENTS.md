# AGENTS.md

## Workflow phases (lean)

- A **phase is lean**: a small, coherent goal; **only a handful of commits** per phase, each continuing the same thread of work — never a sprawl of micro-fixes.
- **End-of-phase validation (only when the phase warrants it)**: if a phase changes behaviour that can be tested (logic, I/O, DB, output contract), close it with a dedicated micro-task that runs the tests covering what that phase built — add or extend a test when no suite covers it. Open the phase PR only after that task is green, and commit the test work on the phase branch. Documentation-only, formatting, or other non-behavioural phases need no test micro-task; `ci.sh` staying green is enough. When in doubt, ask whether the change could break at runtime — if not, skip the test task.
- `ci.sh` — the repo's one-shot check command: static COBOL checks, build, both test suites. Run it before committing; it must exit 0 with `ALL GREEN`.
- `build.sh` — compiles all COBOL modules + `sql_bridge.c` into a single binary (`cobol/bin/main_logic`). Edit this file, never an ad-hoc `cobc` invocation.
- `tests/test_suite.sh`, `tests/test_atomic_txn.sh` — functional and atomic-transaction suites. Both need the MySQL database `cobol_db` seeded via `database/schema.sql` + `database/seed_test_data.sql`; each suite resets DB state itself.

## Routing contract (edit together)

Action names are matched across `cobol/src/main_logic.cob` (routing) and the module that owns them: `CHECK_BALANCE`, `TRANSFER`, `RECONCILE` in `cobol/src/wallet_core.cob`; `GET_USER`, `LIST_USERS` in `cobol/src/user_core.cob`; `AUTH_LOGIN`, `REQUEST_SIGNUP`, `VERIFY_EMAIL` in `cobol/src/auth_core.cob`. Adding or renaming an action requires editing the router and the owning module together; review must check they agree.

## I/O architecture

The binary reads one pipe-delimited line from `input.txt` and writes exactly one result line to `output.txt`. Args format: `ACTION|param1|param2|param3|param4`. The two files are relative to the process working directory, so concurrent callers must each run the binary in their own directory — see `docs/adr/0001-invocation-model.md`.
