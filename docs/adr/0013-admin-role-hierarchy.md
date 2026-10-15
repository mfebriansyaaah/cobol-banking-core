# Admin role hierarchy and separation of duties

Status: accepted
Date: 2026-10-15
Phase: Admin/Governance hardening (FASE A).

## Context

Roles are `USER`, `MANAGER`, `SUPER_ADMIN` (rank 1/2/3). Identity always comes
from the bearer token and the role is read live from the database, but the
`SUPER_ADMIN or MANAGER` checks (`ALLOW-ADMIN`, `ALLOW-READ`) treated a MANAGER
as an equal of a SUPER_ADMIN for user administration. An audit proved a MANAGER
could `SET_USER_STATUS` a SUPER_ADMIN to `SUSPENDED` (and revoke its sessions),
locking the primary administrator out.

## Decision

- Introduce a numeric rank: `USER=1 < MANAGER=2 < SUPER_ADMIN=3`.
- An actor may not administer an account ranked **above** it, i.e.
  `actorRank >= targetRank` is required for actions that affect another account:
  - `SET_USER_STATUS` (status/verification changes), and
  - `REVOKE_USER_SESSION` / `REVOKE_ALL_SESSIONS` (force-logout).
- Equal ranks are allowed, so a SUPER_ADMIN can act on a peer for incident
  response; self-service is always allowed. Reads (`LIST_SESSIONS`, profile
  reads) keep the self-or-admin rule and are not rank-restricted in this phase.

## Consequences

- A lower-ranked admin (e.g. MANAGER) can never suspend, close, verify or
  force-logout a higher-ranked account (e.g. SUPER_ADMIN). The privilege
  escalation found in the audit is closed.
- Peers can still manage each other, which keeps incident response possible.
  Preventing the removal of the **last** SUPER_ADMIN (so a peer action cannot
  empty the admin role) is the next phase (FASE B), building on the same rank
  helper.
- The rule is enforced in COBOL (the business-logic boundary), independently of
  the gateway, and covered by `tests/test_admin_hierarchy.sh`.
