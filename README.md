# Cobol Banking Core

An enterprise-style banking core where **all business logic lives in COBOL**, with
C and JavaScript as support only.

- `cobol/bin/main_logic` — one COBOL binary. By default it reads one
  pipe-delimited request line from `input.txt` and writes one result line to
  `output.txt` (`ACTION|param1|param2|param3|param4`); with `--serve` it runs
  long-lived, reading request lines from stdin and writing one result line per
  request to stdout.
- `cobol/src/sql_bridge.c` — C bridge to MySQL (`libmysqlclient`): prepared
  statements, escaping, and transactions. `cobol/c_lib/hash_lib.c` — PBKDF2 hashing
  (600000 iterations by default, rehashed on login when below target) and secure code generation.
  `cobol/c_lib/totp_lib.c` — TOTP for MFA. `cobol/c_lib/settings_lib.c` — read optional limits from the environment.
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
cat output.txt                 # -> SUCCESS|BALANCES|USD:1000.00:ACTIVE

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

The COBOL binary reads its database connection from the environment
(`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASS`, `DB_NAME`; development defaults);
the gateway passes its environment through to the binary it spawns.

Invocation is one process per request by default. Set `COBOL_POOL_SIZE` to run a
warm worker pool over the binary's `--serve` mode instead (ADR-0010);
`COBOL_POOL_PIPELINE` caps in-flight requests per worker.

Security headers are set with `helmet`. In production (`NODE_ENV=production`)
the server refuses to start while `JWT_SECRET`/`REFRESH_SECRET` are unset or
still the development defaults. Tokens carry an issuer and audience
(`JWT_ISSUER`/`JWT_AUDIENCE`) that verification enforces.

Verification codes are delivered out of band (`SMTP_*`, or a development stub
that logs the event without the code) and are never returned in HTTP responses.
Access tokens carry a per-user version that is checked on every request and is
bumped on logout (`REVOKE_TOKENS`), so an access token can be revoked before it
expires. A single token can also be denied by `jti` via `POST /auth/revoke`; the
denylist is shared (DB) behind a `tokenStore` seam.

Accounts can add a TOTP second factor: `POST /mfa/enroll` returns the secret and
an `otpauth://` URI, `POST /mfa/confirm` turns it on, and once enabled
`POST /auth/login` also needs the current `mfaCode`. Passwords use PBKDF2-SHA256
(600000 iterations, rehashed on login when below target). Users can see their
active sessions (`GET /sessions`), revoke one (`POST /sessions/revoke`), or log
out everywhere (`POST /sessions/revoke-all`).

Responses use one envelope - success `{ data: [...] }`, failure
`{ error, detail? }`. `/users` is paged (`limit` 1..100, `offset`).

Transfers convert the target credit using `exchange_rates` (base -> target) when
the accounts use different currencies; if only the inverse pair exists its
reciprocal is used, and a pair with neither direction fails with `RATE_NOT_FOUND`.
Debit/credit are rounded to each currency's precision and the applied rate is
recorded on the `ledger` CREDIT row. A transfer only goes through when both
accounts are `ACTIVE` and both currencies are enabled (otherwise `ACCOUNT_FROZEN`
/ `ACCOUNT_CLOSED` / `CURRENCY_INACTIVE`). `POST /wallet/transfer` requires an
`Idempotency-Key` header; retrying with the same key replays instead of moving
money twice (keys are scoped per sender). Optional caps `TRANSFER_MAX_PER_TXN`
(one debit) and `TRANSFER_DAILY_LIMIT` (rolling 24h per account) are off unless
set in the environment. A SUPER_ADMIN can reverse a transfer once
(`POST /transactions/:ref/reverse`), and its status is readable at
`GET /transactions/:ref`.

The binary writes its result in 500-char records; the gateway reassembles them,
so large list responses are not cut at 500 bytes.

Rate-limit counters are per process by default; set `REDIS_URL` to share them
across gateway instances, and `TRUST_PROXY` when behind a proxy so the client
IP is read from the forwarded headers.

Metrics are exposed at `GET /metrics`; set `METRICS_PUSH_URL` to also push them
periodically to a collector (Pushgateway/OTLP-HTTP).

Audit retention: `POST /admin/audit/archive` (SUPER_ADMIN) moves `audit_trail`
rows older than a retention window into the immutable `audit_trail_archive`.

Public routes: `/health` (deep), `/auth/signup`, `/auth/verify`, `/auth/login`,
`/auth/forgot`, `/auth/reset-password`, `/auth/resend`, `/auth/refresh`, `/auth/logout`. Everything else needs a bearer token; the
acting identity always comes from the token, never the request body. Reads of a
user's record/balance/profile allow the owner or an admin, listing users is
admin-only, a transfer is always sent from the token's account, and the
email-change flow only acts on the token's own email. Each request runs the
binary in its own working directory (see
`docs/adr/0001-invocation-model.md`); responses carry `X-Cobol-Ms` and
`X-Request-Id`. The server logs one JSON line per request and serves
Prometheus-style counters at `GET /metrics` (bearer).

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
  `commit-msg` hook refuses commits directly on `main`/`master`, except the
  deliberate `docs: sync ...` post-merge documentation commit.
- Gateway smoke tests: `npm --prefix middleware test` includes
  `endpoints.test.js`, which exercises every route; `./tests/test_e2e_gateway.sh`
  drives a full flow over real HTTP against a live server (run by `ci.sh`).
- Shell safety: to stop stray servers, match with a bracket pattern
  (`pkill -f "[s]erver.js"`) so the pattern does not match the command itself.
