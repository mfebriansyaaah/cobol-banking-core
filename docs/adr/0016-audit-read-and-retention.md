# Reading and bounding the audit trail

Status: accepted
Date: 2026-10-15
Phase: Admin/Governance hardening (FASE D).

## Context

The audit trail was write-only from the API: the only endpoint was
`POST /admin/audit/archive`, so answering "what happened" required direct
database access. The archiver also accepted `days` of any value; `0` archived
every live row in a single call (moving essentially the whole trail to the
archive), and the retention value was not validated in COBOL.

## Decision

- Add the `LIST_AUDIT` action and `GET /admin/audit`, **SUPER_ADMIN only**:
  - filters: `action` (optional, validated upper-case token) and `email`
    (optional, the subject);
  - paging: `limit` (default 50, gateway caps 1..100) and `offset`;
  - returns `SUCCESS|AUDIT|<total>|<rows>` where each row is
    `id:created:action:subject:actor:entity_type:entity_id:status:detail`
    (the free-form `detail` has `|`/`;` replaced so it cannot break the row
    format).
- `ARCHIVE_AUDIT` now requires a retention of **at least one day**, validated in
  COBOL (the leading digit must be 1..9), returning `ERROR|INVALID_INPUT`
  otherwise. The gateway's integer pattern already rejects non-digits.

## Consequences

- Administrators can inspect the trail (including who acted, via `actor_id`)
  without database access.
- The "one call wipes the live trail" foot-gun is closed; a caller must ask for
  a real retention window.
- The read is a normal paged list; there is no export/streaming yet, and the
  archive itself is not exposed for reading.
- Covered by `tests/test_audit_read.sh` and a gateway test.
