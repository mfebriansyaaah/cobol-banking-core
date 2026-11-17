# Session Audit Cleanup Review

This branch documents the audit/cleanup work completed on 2026-10-27/28.
The code changes are already present in `main`; this branch is a review
artifact because `main` fast-forwarded past the original working tree.

## Scope

### Core / COBOL

- `main_logic.cob`: table-driven dispatcher (200 entries) replacing the if-chain.
- `auth_core.cob`, `user_core.cob`, `wallet_core.cob`: warning baseline 0.
- `hashlen_core.cob`: END-COMPUTE terminator.
- `loan_core.cob`: `LOAN_APPLY`, `LOAN_APPROVE`, `LOAN_REJECT`, `LOAN_DISBURSE`, `LOAN_REPAY`.
- `sql_bridge.c`: thread-local query/result/connection state.
- `user_core.cob`: `WS-RLEN` uses `FUNCTION TRIM(... TRAILING)` (fixes long IPC output).

### Gateway / API

- `gl_allocation.js`: `GLA_ALLOCATE` corrected to `GLA_ALLO`.
- `field_order.test.js` + contract fixture: account/user field order locked.
- `check_manifest.mjs`, `check_route_dispatch.mjs`, `check_action_coverage.mjs`: updated for table dispatch and exact coverage.
- `KCP_UPDATE` recorded as an explicit known gap.

### Tests

- 72 new `.cases` files; table suite now 300 assertions.
- 3 pre-existing gateway failures fixed:
  - IPC contract: 500-char output joined.
  - IPC contract (pool): long output joined.
  - Gateway: large list not truncated at 500 bytes.

### Docs

- `docs/adr/0002-concurrency-model.md`
- `docs/module_classification.md`
- README status/known-gaps updates.

## Diff summary (vs 19e9e4e)

See `git diff --stat 19e9e4e..main -- <files>` for the exact per-file diff.
