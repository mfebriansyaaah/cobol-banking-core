# Last-admin protection

Status: accepted
Date: 2026-10-15
Phase: Admin/Governance hardening (FASE B).

## Context

Roles rank `USER=1 < MANAGER=2 < SUPER_ADMIN=3` (ADR 0013). Only a SUPER_ADMIN
may change roles, run the reconciliation, archive the audit trail or reverse a
transfer, and only an admin may change an account's status. If the final active
SUPER_ADMIN is demoted, suspended, closed or self-deactivated, nobody can
perform those actions again through the API — the system is locked out.

## Decision

- The system must always keep at least one **active** (status `VERIFIED`)
  `SUPER_ADMIN`. A change is refused with `ERROR|LAST_ADMIN` (HTTP 409) when it
  would leave zero:
  - `CHANGE_ROLE`: demoting the target away from `SUPER_ADMIN`;
  - `SET_USER_STATUS`: setting the target to anything other than `VERIFIED`
    (i.e. `SUSPENDED`/`CLOSED`/`UNVERIFIED`);
  - `DEACTIVATE_ACCOUNT`: the owner self-closing the account.
- The rule counts across the whole system (any other active SUPER_ADMIN, not
  just the actor's peers), so equal-rank actions stay possible while the
  invariant holds.
- Recovery when the admin population is genuinely lost is **out-of-band**: a
  database administrator sets `role='SUPER_ADMIN'` (and `status='VERIFIED'`) for
  a trusted account. This is the documented break-glass.

## Consequences

- The API can no longer empty its own administrator role; the last admin is
  protected from self-inflicted lockout and from a peer.
- A legitimate handover is still possible: promote a new SUPER_ADMIN first (a
  second active super), then demote the old one.
- The check reads current state on every call (no cache), consistent with the
  live role checks elsewhere; covered by `tests/test_last_admin.sh`, which
  isolates the shared test database by suspending and restoring other supers.
