# ADR 0004 — 16KB Result Buffer: Fail Loud, Never Silent-Cut

## Status

Accepted (PR-061).

## Context

The C bridge returns rows through a fixed 16KB (`G_RESULT`) buffer. Overlong
results were silently truncated by `strncat`: the client received a
well-formed but incomplete response with no signal that rows were missing.

## Decision

- The bridge tracks output against the buffer bound during fetch. On
  overflow it returns `ERROR|RESULT_TRUNCATED` (HTTP 500) instead of a cut
  response. A row cap (2000 rows) bounds `store_result` memory the same way.
- Single-row fetches surface the error exactly. Multi-row list actions that
  prefix a separate `COUNT(*)` envelope keep their envelope with the marker
  appended (`SUCCESS|KIND|n|ERROR|RESULT_TRUNCATED`): clients must treat a
  response containing the marker as truncated, not as `n` delivered rows.
- Per-action envelope propagation (returning the bare error from every list
  action) is deferred: it touches every list envelope identically and is
  lower value than the bridge-level guarantee.

## Consequences

- Legal requests can hit the bound (e.g. 100 wide audit rows); callers page
  tighter or filter more. `tests/db/truncation_db_tests.sh` pins both sides.
- `RESULT_TRUNCATED` is a distinct error code (gateway 500) so dashboards
  can alert on it separately from `DB_ERROR`.
