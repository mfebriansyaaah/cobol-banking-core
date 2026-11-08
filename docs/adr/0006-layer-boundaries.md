# ADR 0006: Layer boundaries for gateway, adapters, services, COBOL, and C

## Status

Accepted (Option A — pragmatic signals).

## Context

The banking backend splits responsibilities across four runtimes:

- **COBOL** is the authoritative business tier. Every balance, limit,
  status transition, and ledger mutation is decided and executed in COBOL.
- **Node/Express gateway (`middleware/src`)** is transport only: routing,
  input-shape validation, authentication handoff, COBOL invoke, HTTP mapping.
- **Adapters (`middleware/adapters`)** reshape external provider responses
  into internal signals. They may classify provider output
  (`VALID/INVALID`, `CLEAR/POTENTIAL_MATCH/MANUAL_REVIEW`, risk flags),
  but they never perform domain state transitions.
- **Services (`middleware/services`)** own domain-adjacent policy and
  integrations (mailer, screening, OCR, risk, quota, resilience).
- **Workers (`middleware/workers`)** run background jobs (outbox dispatch).
- **C (`cobol/src/sql_bridge.c`, `cobol/c_lib`)** owns DB connectivity and
  crypto primitives COBOL cannot call directly.

Two dependency inversions grew historically:

1. `middleware/services/*` imported from `middleware/src/observability.js`.
2. `middleware/workers/outbox.js` imported from `middleware/src/*`.

`scripts/check_gateway_purity.mjs` only checked `src → services`, not the
reverse, so the inversion was invisible to CI.

`middleware/src/derivations.js` also mixed adapter work (NIK structure,
screening verdict, OCR confidence, risk flags, phone normalization) into
the transport layer.

## Decision (Option A)

Pragmatic signals, COBOL decides:

1. **One-way dependencies only.**

```text
http/routes → adapters → services
     ↓            ↓           ↓
 core-client ← telemetry (shared leaves)
     ↓
 COBOL binary --pipe--> C bridge --> MariaDB
```

- `middleware/src` (transport) may import `core-client`, `telemetry`,
  and `adapters`, never `services` or `workers` directly.
- `middleware/adapters` may import `services` and `core-client`/`telemetry`,
  never `src`.
- `middleware/services` may import `telemetry` and `core-client`, never `src`.
- `middleware/workers` may import `core-client`, `telemetry`, `services`,
  and `adapters`, never `src`.
- `middleware/core-client` (COBOL transport) and `middleware/telemetry`
  are leaves: they import only Node builtins (and each other in one
  direction: `core-client → telemetry` for counters, never reverse).
- COBOL modules may `CALL` only allowlisted modules. One transaction has
  one owner (see `scripts/check_transaction_ownership.mjs`, future work).
- C bridge owns connectivity/crypto only. No truncation, no newline
  framing leaks, no partial-row success (see P0-4 fixes).

2. **Signals vs decisions.**

- Adapters return **signals**: `nikStructuralValid`, `providerResultSignal`,
  `ocrConfidenceSignal`, `riskFlagsSignal`, `phoneE164Signal`, plus
  content-addressed handles (`nikHash`, `phoneHash`, `queryHash`, `ipHash`).
- Legacy COBOL field names (`verdict`, `result`, `ipHashFlags`) are kept as
  **aliases** during migration so the 6-slot pipe contract does not break.
  `middleware/src/app.js` maps signals → COBOL params; COBOL performs the
  state transition (`NIK_VALID`, `SCREEN_RECORDED` + review row, `RISK_NOTED`,
  `LINK_BEGIN`, `OCR_RECORDED`).
- Raw PII (NIK, phone, IP) never reaches COBOL, DB, or logs — only hashes
  travel, as before.

3. **Canonical locations.**

- `middleware/core-client/`: `binary.js`, `errors.js`, `invoker.js`,
  `pool.js`, `result.js` (COBOL transport).
- `middleware/telemetry/`: `observability.js` (metrics/logs).
- `middleware/adapters/signals.js`: server-side derivations (ex-`derivations.js`).
- `middleware/src/*` files remain as thin re-export shims during migration,
  then become transport-only facades. New code imports the canonical path.

## Consequences

- `scripts/check_gateway_purity.mjs` + new
  `scripts/check_dependency_graph.mjs` enforce one-way imports and fail CI
  on `services → src`, `workers → src`, `adapters → src`, cycles, and
  direct DB/SQL in transport.
- Probes in `tests/probes/` gain a boundary case: reverse import must be
  `detected`.
- COBOL contract unchanged on the wire (same 6 slots, same `SUCCESS|…` /
  `ERROR|…` framing); comments and signal aliases make ownership explicit.
- Follow-ups (not in this ADR): typed contract registry
  (`contracts/actions.yaml`), transaction-ownership gate, COBOL call-graph
  allowlist, length-prefixed IPC framing.

## Evidence

- `middleware/test/trust-boundary.test.js` (signals overwrite client input).
- `middleware/test/contract.test.js`, `route-reachability.test.js`.
- `scripts/test/check_gateway_purity.test.mjs`,
  `scripts/test/check_dependency_graph.test.mjs` (new).
- `docs/IDENTITY.md`, `docs/AML.md`, `docs/RISK.md` (trust-boundary sections).
