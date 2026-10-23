# Cobol Banking Core

A banking core for a licensed production service where **all business logic is
authoritative in COBOL**. C and JavaScript are restricted to infrastructure
adapters and capabilities COBOL cannot provide directly.

> **Production status:** owner approvals are recorded in `docs/APPROVALS.md`;
> signed evidence is retained in the private evidence store and is not
> reproduced here. This repository is the engineering artifact and does not
> itself constitute regulatory approval. Gate 0 decisions and evidence are
> tracked in `docs/GATE0_PACKET.md`, `docs/TRACEABILITY.md`, and
> `docs/STATUS.md`.

## Architecture

- `cobol/bin/main_logic` - one COBOL binary. By default it reads one
  pipe-delimited request line from `input.txt` and writes one result line to
  `output.txt`; with `--serve` it handles one request per stdin line (the
  worker-pool protocol).
- `cobol/src/sql_bridge.c` - C bridge to MySQL (prepared statements, escaping,
  transactions). `cobol/c_lib/` holds PBKDF2, TOTP, settings, and CSPRNG
  helpers.
- `middleware/` - Node.js/Express API gateway, the only HTTP interface. It
  validates input, invokes the binary, and maps result lines to HTTP.
- Curated COBOL modules:
  - `wallet_core.cob` - ledger, transfers, holds, reversals, statements,
    disputes, reconciliation.
  - `auth_core.cob` - identity, sessions, MFA, access reviews, policies.
  - `user_core.cob` - users, profile, lifecycle.
  - `ref_engine.cob` - generic reference data.
  - `gl_core.cob` - chart of accounts, period control, journals, trial balance.
  - `batch_core.cob` - jobs, steps, checkpointed runs, control totals, retry.
  - `report_core.cob` - report templates, columns, runs, rows, and export.
  - `import_core.cob` - staged batches, row validation, correction, posting,
    and export.
  - `fee_core.cob` - fee rules/tiers/waivers, duration limits, and velocity.
  - `eod_core.cob` - EOD calendar, runs, phases, close, and fail control.
  - `statement_core.cob` - period statement archive, lines, and export.
  - `eod_jobs_core.cob` - hold expiry, dormant jobs, reconciliation, and
    statement EOD execution.
  - `ref_ext_core.cob` - translations, hierarchy, as-of lookup, clone, export.
  - `notification_core.cob` - templates, preferences, and outbox enqueue.
  - `payment_core.cob` - per-currency limits, user overrides, and usage checks.
  - `recon_core.cob` - reconciliation notes, assignment, aging, and export.
  - `import_post_core.cob` - balanced LEDGER import posting into the GL journal.
  - `report_delivery_core.cob` - fixed-width layouts and recurring report delivery.
  - `dispute_ops_core.cob` - dispute SLA, queue, assignment, escalation, and aging.
  - `export_archive_core.cob` - retained report/import exports with checksum and expiry.
  - `recon_ops_core.cob` - assignment rules, auto-assignment, and owner workload.
  - `alert_core.cob` - operational alerts with scans, acknowledgement, and history.
  - `dashboard_core.cob` - read-only cross-domain operational dashboards.
  - `statement_recon_core.cob` - statement-to-ledger matching and recon runs.
  - `payment_instruction_core.cob` - standing instructions and execution history.
  - `oncall_core.cob` - rotations, shifts, escalation steps, and pages.
  - `audit_analytics_core.cob` - audit summaries, trends, anomalies, retention, snapshots.
  - `import_recon_core.cob` - import-to-GL reconciliation runs and exception items.
  - `recon_exception_core.cob` - reconciliation exception cases, notes, SLA, and closure.
  - `dispute_notify_core.cob` - dispute customer notification templates and delivery tracking.
  - `export_stream_core.cob` - time-limited, counted export download tokens and chunk streaming.
  - `alert_escalation_core.cob` - escalation policies, steps, and paged run tracking.
  - `audit_drilldown_core.cob` - saved audit drill-down queries and ad-hoc audit pivots.
  - `compliance_export_core.cob` - compliance export packages with seal, attest, and checksum verification.
  - `legal_hold_core.cob` - legal holds with placement, release, and hold-blocking checks.
  - `key_rotation_core.cob` - key rotation plans with bounded overlap and audit.
  - `dsar_core.cob` - data subject access requests, export/erase, legal-hold blocking.
  - `retention_job_core.cob` - retention policies and runs honouring legal holds.
  - `slo_report_core.cob` - SLO definitions and burn-rate measurements.
  - `pipeline_alert_core.cob` - idempotent pipeline failure alerts.
  - `incident_core.cob` - incident lifecycle, assignment, and resolution.
  - `change_control_core.cob` - change requests, approval, deploy, rollback.
- `cobol/src/generated/ref_core.cob` - frozen generated reference module:
  206 entities, 1,030 actions. It is a volume-sprint artifact, excluded from the
  production coverage target, and must not grow.
- MySQL database `cobol_db`.

## Current state and target

Measured 2026-10-23:

| Metric | Value |
|---|---:|
| Non-generated net | **109.936** |
| Curated COBOL net | **56.831** (51,6%) |
| Total COBOL net | **108.965** |
| Full CI | **148 steps / 2252 assertions** |
| Non-generated gap to 100.000 | **0** |

The target is **100.000 non-generated net**, **>= 60.000 total COBOL**, and
**>= 50.000 curated COBOL** at **>= 50%** share. Volume is a constraint, not a
production-readiness claim.

## Delivery rules (mandatory)

Read `docs/DELIVERY_RULES.md` before starting work. In short:

- **One PR = two modules**, target **5.000-6.500 net**.
- **One full CI, one push** at the end.
- **15-minute interface freeze** before code.
- **Parallel worktrees/subagents** after the freeze.
- **Table-driven tests** wired into `ci.sh` and `tests/baseline_counts.txt`.
- **`./scripts/finalize_slice.sh`** before the full gate.
- **One review per PR**; merge before starting the next slice.
- No generated `ref_core` growth, padding, duplicate paragraphs, or dead
  actions.

## Quick start

Prerequisites: GnuCOBOL (`cobc`), `gcc`, `libmysqlclient-dev`, MySQL/MariaDB,
the `mysql` client, and Node.js 18+ with npm.

```sh
# 1. Database: create, apply baseline schema, seed dev fixtures, migrate
mysql -u root -e "CREATE DATABASE IF NOT EXISTS cobol_db;"
mysql cobol_db < database/schema.sql          # fresh install only
mysql cobol_db < database/seed_test_data.sql # dev fixtures, safe to re-run
database/migrate.sh                          # apply recorded migrations

# 2. Build the COBOL binary
./build.sh

# 3. Run one action
printf 'CHECK_BALANCE|sender@test.com|sender@test.com||\n' > input.txt
./cobol/bin/main_logic
cat output.txt                                # SUCCESS|BALANCES|USD:1000.00:ACTIVE

# 4. Full gate
./ci.sh                                       # must end with ALL GREEN
```

Test credentials default to `cobol_user`/`cobol_pass` on `cobol_db`; override
via `tests/.dbenv` (gitignored). Production uses least-privilege accounts from
`database/grants.sh`.

## API gateway

```sh
npm --prefix middleware install
npm --prefix middleware start
```

The gateway reads `middleware/.env` (see `.env.example`). The COBOL binary
reads `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASS`, and `DB_NAME` from its
environment. Set `COBOL_POOL_SIZE` to use the warm worker pool; otherwise each
request runs in its own working directory. Responses carry `X-Cobol-Ms` and
`X-Request-Id`; metrics are exposed at `/metrics` for a SUPER_ADMIN bearer.

Behavior is specified per module in `SPEC-wallet-core.md`,
`SPEC-auth-identity.md`, `SPEC-user-profile.md`, and `SPEC-api-gateway.md`.
Requests must use the bearer token as the acting identity; the gateway never
takes the actor from the body.

## Documentation

- `docs/DELIVERY_RULES.md` - mandatory slice workflow, volume target, and
  definition of done.
- `docs/STATUS.md` - current modules, actions, tables, suites, and known gaps.
- `docs/PRODUCTION_GRADE_PLAN.md` - production workstreams, gates, and risks.
- `CODING_STANDARDS.md` - review rules.
- `docs/APPROVALS.md`, `docs/GATE0_PACKET.md`, `docs/GATE0_DECISIONS.md`,
  `docs/TRACEABILITY.md` - owner decisions, evidence, and requirement mapping.
- `docs/COVERAGE.md`, `docs/BUILD_WARNINGS.md`, `docs/BUFFER_CONTRACT.md`,
  `docs/SCHEMA_POLICY.md` - measurement and contract policies.
- `docs/runbooks/` - incident, alert, backup/restore, deploy/rollback, and
  secret-rotation procedures.
- `docs/adr/` - architecture decisions.

## Development notes

- Install hooks once per clone: `./scripts/install-hooks.sh`.
- Start a slice from merged `main`: `./scripts/sync_main.sh <branch>`.
- Use `./ci-fast.sh` while iterating; full `./ci.sh` is the merge evidence.
- Functional shell suites use `tests/serve_harness.sh` unless they need
  fresh-process semantics.
- Stop stray servers with a bracket pattern (`pkill -f "[s]erver.js"`).

See `PRD_Enterprise.md` for the regulated-bank mission and release gates.
