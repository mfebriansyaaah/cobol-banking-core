# Scoped permissions

Status: accepted
Date: 2026-10-20
Phase: Gate 2 (access control). Narrows the `SUPER_ADMIN` blast radius from
requirement `A-P0-ACCESS` in `docs/TRACEABILITY.md`.

## Context

Privileged access in this system is a single ladder: `USER < MANAGER <
SUPER_ADMIN`, and almost every sensitive gate is a hardcoded `role =
SUPER_ADMIN` check. That concentrates unrelated powers — reading the audit
trail, archiving it, running reconciliations, resolving exceptions, changing
roles — in one rank. Any operator who needs one of those powers must hold all
of them, and a future read-only auditor role cannot exist without touching
every gate.

## Decision

1. **Permissions are data, not code.** A `permissions` catalog names each
   capability (`AUDIT_READ`, `AUDIT_ARCHIVE`, `RECONCILE_READ`,
   `RECONCILE_RUN`, ...); a `role_permissions` table maps roles to the
   permissions they hold. Adding a capability or reassigning it is a data
   change reviewed like any schema change, not a code edit in every guard.
2. **Phase 1 changes the mechanism, not the access.** The default mapping
   reproduces exactly the current behavior: `SUPER_ADMIN` holds every
   permission in the catalog, `MANAGER` and `USER` hold none of the new ones.
   No operator gains or loses access in this phase; the refactor is
   behavior-preserving by construction and proven by the unchanged
   hierarchy suites.
3. **The check lives in COBOL.** `CHECK_PERMISSION` answers whether an
   account holds a permission, `LIST_PERMISSIONS` lists what an account
   holds, and the `ALLOW-PERMISSION` helper replaces the hardcoded
   `SUPER_ADMIN` test in the migrated gates. The gateway never decides
   authorization; it forwards the answer, including the effective permission
   set in the login and profile responses for clients to render.
4. **Phase 1 migrates the read-mostly gates first**: `LIST_AUDIT`,
   `ARCHIVE_AUDIT`, `RECONCILE`, `LIST_RECONCILIATIONS`, `LIST_EXCEPTIONS`,
   and the gateway `/metrics` endpoint. Privileged writes (`CHANGE_ROLE`,
   `SET_USER_STATUS`, revocation, holds, maker-checker, access-review
   decisions) keep their existing rank checks until a later phase assigns
   them permissions with owner approval.
5. **A refused permission is audited** exactly like a refused role: the
   helper records `AUTHZ_DENIED` with the actor before the caller reports
   `FORBIDDEN`.

## Why not new roles

A new `AUDITOR` role value would widen the `users.role` ENUM, and ENUM
changes are the documented non-replayable migration exception in this repo
(`docs/SCHEMA_POLICY.md` rule 3). A permission set named `auditor` carried
as data gives the same read-only shape without touching the ENUM, and a
later owner decision can grant it to a role — or to individual accounts —
without a migration at all.

## Consequences

- Migration `0042`: `permissions` + `role_permissions`, seeded to the current
  behavior.
- Two COBOL actions (`CHECK_PERMISSION`, `LIST_PERMISSIONS`), one helper
  (`ALLOW-PERMISSION`), five migrated gates plus `/metrics`.
- A new error code `PERMISSION_DENIED` (HTTP 403), covered by the gateway
  result-code contract.
- `A-P0-ACCESS` stays `partial` in `docs/TRACEABILITY.md`: the mechanism is
  implemented and tested, but granting any permission to a non-`SUPER_ADMIN`
  role is a Gate 0 owner decision (`docs/GATE0_DECISIONS.md` items 2 and 15)
  and is not done here.
