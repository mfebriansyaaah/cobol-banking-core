# ADR 0001: SQL bridge with max 6 binds

## Status
Accepted

## Context
COBOL modules need to execute SQL. The C bridge (`sql_bridge.c`) exposes `SQL_PREPARE_EXEC` with a fixed 6-bind interface.

## Decision
All domain modules use the 6-bind interface. List queries return rows joined by `;` and fields by `|`. Numerics are bound as text where possible.

## Consequences
- Predictable, simple interface.
- Large lists require string joining; modules must respect 6-bind limit.
