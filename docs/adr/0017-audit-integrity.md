# Audit-trail integrity: evidence survives user deletion, denials are logged

Status: accepted
Date: 2026-10-15
Phase: Admin/Governance hardening (FASE E).

## Context

Two integrity gaps in `audit_trail`:

- Its `user_id` foreign key is `ON DELETE CASCADE`, so deleting a user erased
  that user's entire audit history — evidence destruction.
- Refused authorization attempts (a valid token that is not permitted) left no
  trace, so privilege probing was invisible.

The read path added in ADR 0016 also had no index on `action`/`actor_id`.

## Decision

- **Preserve evidence on deletion** with a `BEFORE DELETE ON users` trigger
  (`trg_audit_snapshot_user_delete`): for the row being deleted it copies the
  user's live `audit_trail` rows into the append-only `audit_trail_archive`
  (which has no foreign key), then the existing cascade removes only the live
  copy. Deleting a user therefore preserves the history in the archive instead
  of destroying it.
- **Record refused authorization** as `AUTHZ_DENIED`: the shared `ALLOW-*`
  guards (auth `ALLOW-READ`/`ALLOW-RANK-ABOVE`, user `ALLOW-READ`/`ALLOW-ADMIN`/
  `ALLOW-RANK-ABOVE`) write an `audit_trail` row when they deny, with the actor
  as subject, the attempted action as `entity_id`, the attempted target as
  `detail`, and `status='FAILED'`. Unknown actors produce no row.
- **Index** `audit_trail(action)` and `audit_trail(actor_id)`.

## Consequences

- Deleting a user no longer destroys their audit history; the durable copy is in
  the immutable archive. (Live rows are still removed, so per-user live queries
  and the test harness keep working.)
- Privilege probing is now visible to administrators via `GET /admin/audit`
  (`AUTHZ_DENIED`).
- The trigger runs per deleted user row; bulk `DELETE FROM users` archives every
  affected user's rows. Covered by `tests/test_audit_integrity.sh`.
- Wallet-side SUPER_ADMIN-only denials (`RECONCILE`, `REVERSE_TRANSFER`) and the wallet self-or-admin reads (`CHECK_BALANCE`) are now also attributed as `AUTHZ_DENIED`;
  this phase covers the auth and user-administration guards.
