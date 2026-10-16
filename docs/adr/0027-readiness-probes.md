# Liveness and readiness probes

Status: accepted
Date: 2026-10-16
Phase: Observability/Operational hardening (FASE C).

## Context

The only health endpoint was `/health`, which runs a deep DB check. Using it as
both a liveness and a readiness probe means a DB blip would fail liveness and
restart the process, and readiness hid the COBOL pool state entirely.

## Decision

- **`GET /live`** (public): returns `200 { status: 'alive' }` unconditionally —
  the process is up. No dependency checks, so it never flaps on a dependency.
- **`GET /ready`** (public): returns `200` when dependencies are usable, else
  `503`:
  - `db`: `up` when `PING` reaches the database, else `down`;
  - `pool`: `up` when the worker pool has a worker, `down` when none,
    `off` when pooling is disabled (file mode).
  Response body: `{ status: 'ready'|'not_ready', checks: { db, pool } }`.
- `/health` stays as the deep, human/ops check (DB reachability with `X-Cobol-Ms`).

## Consequences

- Orchestrators can use `/live` for restarts and `/ready` to gate traffic;
  a DB blip marks the instance not-ready without restarting it, and a broken
  worker pool is surfaced.
- The probes are public (as readiness/liveness probes must be) and reveal only
  coarse dependency states.
- Covered by a gateway test asserting `/live` 200 and `/ready` 200 with `db: up`.
