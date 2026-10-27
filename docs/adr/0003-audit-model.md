# ADR 0003: Audit model with old/new value

## Status
Accepted

## Context
Every domain module needs an audit trail that records who did what and what changed.

## Decision
- Audit table per domain: `_audit` table with columns: id, entity_id, action, actor_email, detail, old_value, new_value, created_at.
- The `AUDIT` COBOL paragraph inserts using 6-bind SQL.
- Old/new values are set by the calling action (CREATE, UPDATE, CLOSE, etc.).

## Consequences
- Consistent audit across all domains.
- Old/new values enable data forensics.
- Storage grows linearly; archiving strategy needed.
