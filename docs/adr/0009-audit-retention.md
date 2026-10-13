# Audit-trail retention via an archive table

Status: accepted
Date: 2026-10-13
Phase: roadmap item - audit retention/archive.

## Context

`audit_trail` is append-only and grows without bound; nothing moved old rows out,
so the live (hot) table would grow forever.

## Decision

- Add `audit_trail_archive`: the same columns plus `archived_at`, and **no**
  foreign key to `users` (the archive is immutable and survives user deletion).
- Add the admin action `ARCHIVE_AUDIT(retentionDays, actor)` (SUPER_ADMIN only,
  routed as `POST /admin/audit/archive`). It moves rows older than the window
  into the archive and deletes them from `audit_trail`, in one transaction:
  `INSERT IGNORE INTO audit_trail_archive (...) SELECT ... WHERE created_at <
  NOW() - INTERVAL n DAY`, then `DELETE ... WHERE created_at < ...`.

## Consequences

- The live table stays bounded; history is retained in the archive.
- Archiving is explicit (an operator/admin action) rather than automatic, so a
  retention run is auditable and does not depend on a scheduler.
- The archive has no cascade, so it can hold rows for deleted users; that is the
  point for compliance retention.
