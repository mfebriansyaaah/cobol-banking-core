# Audit actor attribution

Status: accepted
Date: 2026-10-15
Phase: Admin/Governance hardening (FASE C).

## Context

`audit_trail.user_id` was overloaded: some rows named the subject of an action
(e.g. `SET_USER_STATUS` recorded the target), others named the actor
(`CHANGE_ROLE`, `TRANSFER`). Two admin actions were not attributed to the acting
administrator at all, `REVOKE_USER_SESSION` was not audited, and
`ARCHIVE_AUDIT` left no trace. The PRD requires the trail to answer "who, when,
what, result".

## Decision

- Add an **`actor_id`** column to `audit_trail` and `audit_trail_archive`
  (migration 0024). `user_id` is the **subject** of the action; `actor_id` is who
  performed it. `actor_id` NULL means the subject acted on themselves.
- Populate `actor_id` for every admin-on-other action:
  `SET_USER_STATUS`, `SESSIONS_REVOKED`, `REVOKE_USER_SESSION`.
- **Audit `REVOKE_USER_SESSION`** (subject, actor, session id) and
  **`ARCHIVE_AUDIT`** (actor), the two previously silent actions.
- The archive copies `actor_id` alongside the other columns, so attribution
  survives archiving.

## Consequences

- The trail can answer "which administrator did X to whom", which the old
  `user_id`-only model could not.
- Existing rows keep `actor_id` NULL; readers treat that as "the subject acted
  or the actor is unknown". No backfill is attempted (it cannot be known safely).
- Self-service rows stay NULL by design; the subject and actor coincide.
- Covered by `tests/test_audit_actor.sh`.
