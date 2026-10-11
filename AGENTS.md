# AGENTS.md

## Workflow phases (medium)

- A **phase is medium**: a coherent goal delivered as one PR of **at least five related commits**, each a meaningful step on the same thread. Aim for a healthy daily commit count without sprawl or filler.
- **Atomic commits, not file-sized commits**: split along real boundaries — a schema/field or helper paragraph, the action logic, the router wiring, the docs/SPEC update, the tests — so each commit stands on its own. Every commit carries a real change; a commit that only renames, re-formats, or whitespaces is not a step and reads as spam. Where practical, keep `ci.sh` green at each commit.
- Trivial, non-behavioural changes (a one-line doc fix, a typo) are their own small phase and need not reach five commits; the count is a target for feature/behaviour phases, not a quota to pad.
- **End-of-phase validation (only when the phase warrants it)**: if a phase changes behaviour that can be tested (logic, I/O, DB, output contract), close it with a dedicated micro-task that runs the tests covering what that phase built — add or extend a test when no suite covers it. Open the phase PR only after that task is green, and commit the test work on the phase branch. Documentation-only, formatting, or other non-behavioural phases need no test micro-task; `ci.sh` staying green is enough. When in doubt, ask whether the change could break at runtime — if not, skip the test task.
- `ci.sh` — the repo's one-shot check command: static COBOL checks, build, both test suites. Run it before committing; it must exit 0 with `ALL GREEN`.
- `build.sh` — compiles all COBOL modules + `sql_bridge.c` into a single binary (`cobol/bin/main_logic`). Edit this file, never an ad-hoc `cobc` invocation.
- `tests/test_suite.sh`, `tests/test_atomic_txn.sh` — functional and atomic-transaction suites. Both need the MySQL database `cobol_db` seeded via `database/schema.sql` + `database/seed_test_data.sql`; each suite resets DB state itself.
- `middleware/` — the Node.js/Express API gateway (the only HTTP interface). Transport invokes the binary per request in a unique working directory (see `docs/adr/0001-invocation-model.md`); `npm --prefix middleware test` runs its suite. `ci.sh` runs it too.

## Language (mandatory)

English only for every artifact in this repo: commit messages, PR titles and descriptions, documentation, and source code (identifiers, program/paragraph/variable names, and inline comments). No other language may appear in these artifacts.

## Shell safety

When passing Markdown to `gh pr create` / `gh pr edit`, write the body to a file first and use `--body-file`; backticks inside shell double quotes execute as command substitution.

## Business-logic boundary (mandatory)

COBOL owns **all** business logic: rules, calculations, and state changes. C (`cobol/`) and JavaScript (`middleware/`) are **support only** — DB transport, HTTP transport, input-shape validation, security (JWT, rate limiting), and hashing/random. They must not encode business rules, compute balances, or decide transaction outcomes; they validate the shape of input, invoke COBOL, and translate I/O. A reviewer rejects business logic written outside COBOL.

## Routing contract (edit together)

Action names are matched across `cobol/src/main_logic.cob` (routing) and the module that owns them: `CHECK_BALANCE`, `TRANSFER`, `RECONCILE` in `cobol/src/wallet_core.cob`; `GET_USER`, `LIST_USERS`, `GET_DASHBOARD`, `REQ_EMAIL_CHANGE`, `CONFIRM_EMAIL_CHANGE` in `cobol/src/user_core.cob`; `AUTH_LOGIN`, `REQUEST_SIGNUP`, `VERIFY_EMAIL`, `CHECK_ROLE`, `CHANGE_ROLE` in `cobol/src/auth_core.cob`. Adding or renaming an action requires editing the router and the owning module together; review must check they agree.

## I/O architecture

The binary reads one pipe-delimited line from `input.txt` and writes exactly one result line to `output.txt`. Args format: `ACTION|param1|param2|param3|param4`. The two files are relative to the process working directory, so concurrent callers must each run the binary in their own directory — see `docs/adr/0001-invocation-model.md`.
