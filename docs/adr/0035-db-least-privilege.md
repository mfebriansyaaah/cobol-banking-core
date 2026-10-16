# Least-privilege database accounts

Status: accepted
Date: 2026-10-16
Phase: Cross-domain security hardening (FASE C).

## Context

The single database account used by the application held `ALL PRIVILEGES` on
`cobol_db`, including DDL (`CREATE`/`DROP`/`ALTER`). Prepared statements and
the whitelist path already mitigate injection, but if any code path ever
executed attacker-influenced DDL the blast radius would be the whole schema.
A runtime account should not be able to change the schema at all.

## Decision

- Add `database/grants.sh` (run as a database admin) that provisions two
  accounts on the data database:
  - the **application** account (`cobol_app` by default): `SELECT, INSERT,
    UPDATE, DELETE` only — no DDL;
  - the **migration** account (`cobol_migrate` by default): full rights,
    restricted to the one database.
  `database/grants.sh --print` emits the statements with password placeholders
  so they can be reviewed without executing.
- `database/migrate.sh` now connects as `DB_MIGRATE_USER`/`DB_MIGRATE_PASS`
  (falling back to `DB_USER`/`DB_PASS`), so schema changes run under the
  privileged account while the running app uses the DML-only one.
- `middleware/.env.example` and the README document that production `DB_USER`
  is the DML-only account.

## Consequences

- A runtime bug or injection cannot `DROP`/`ALTER` the schema; migrations keep
  working under their own credential.
- Provisioning the accounts is a one-time admin action and is **not** exercised
  in CI (the test environment has no database admin); `tests/test_grants.sh`
  instead guards the invariant statically — the app grant is DML-only and has
  no DDL keyword, the migration grant is full, the accounts differ, and
  `migrate.sh` supports the separate credential.
- Defaults stay backward compatible (`cobol_user`/`cobol_pass`) for existing
  development setups; adopting the split is a deployment step.
