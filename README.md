# Cobol Banking Core

An enterprise-style banking core where **all business logic lives in COBOL**, with
C and JavaScript as support only.

- `cobol/bin/main_logic` — one COBOL binary. It reads one pipe-delimited request
  line from `input.txt` and writes one result line to `output.txt`
  (`ACTION|param1|param2|param3|param4`).
- `cobol/src/sql_bridge.c` — C bridge to MySQL (`libmysqlclient`): prepared
  statements, escaping, and transactions. `cobol/c_lib/hash_lib.c` — PBKDF2 hashing
  and secure code generation.
- `middleware/` — Node.js/Express API gateway, the only HTTP interface; it
  validates input shapes, invokes the binary per request (own working directory),
  and maps the result line to HTTP.
- MySQL database `cobol_db`.

See `docs/STATUS.md` for the full current state and `SPEC-*.md` per module.

## Prerequisites

GnuCOBOL (`cobc`), `gcc`, `libmysqlclient-dev`, a MySQL/MariaDB server, the `mysql`
client, and Node.js 18+ with npm.

## Quick start

```sh
# 1. Database: create, apply schema, seed test data, apply migrations
mysql -u root -e "CREATE DATABASE IF NOT EXISTS cobol_db;"
mysql cobol_db < database/schema.sql
mysql cobol_db < database/seed_test_data.sql
database/migrate.sh            # records/applies database/migrations/NNN_*.sql

# 2. Build the COBOL binary
./build.sh

# 3. Run one action
printf 'CHECK_BALANCE|sender@test.com|||\n' > input.txt
./cobol/bin/main_logic
cat output.txt                 # -> 1000.00

# 4. Run everything (static checks, build, all suites)
./ci.sh                        # must end with "ALL GREEN"
```

Test credentials default to `cobol_user`/`cobol_pass` on `cobol_db`; override via
`tests/.dbenv` (gitignored). See `database/migrate.sh --check` for pending
migrations.

## API gateway

```sh
npm --prefix middleware install
npm --prefix middleware start     # reads middleware/.env (see middleware/.env.example)
```

Public routes: `/health` (deep), `/auth/signup`, `/auth/verify`, `/auth/login`,
`/auth/refresh`, `/auth/logout`. Everything else needs a bearer token. Each
request runs the binary in its own working directory (see
`docs/adr/0001-invocation-model.md`); responses carry `X-Cobol-Ms`.

## Where things are documented
- `AGENTS.md` — workflow, language, business-logic boundary, routing contract, I/O.
- `CODING_STANDARDS.md` — rules a reviewer enforces.
- `SPEC-wallet-core.md`, `SPEC-auth-identity.md`, `SPEC-user-profile.md`,
  `SPEC-api-gateway.md` — per-module as-built behaviour and gaps.
- `docs/STATUS.md` — current-state snapshot; `docs/HISTORY.md` — merged phases.
- `docs/adr/` — architecture decisions.
- `database/migrate.sh` — versioned schema migrations.

## Development notes

- Install the tracked git hooks once per clone: `scripts/install-hooks.sh`. The
  `pre-commit` hook refuses commits directly on `main`/`master`.
- Gateway smoke test: `npm --prefix middleware test` includes `endpoints.test.js`,
  which exercises every route.
- Shell safety: to stop stray servers, match with a bracket pattern
  (`pkill -f "[s]erver.js"`) so the pattern does not match the command itself.
