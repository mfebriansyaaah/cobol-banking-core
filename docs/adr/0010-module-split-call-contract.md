# ADR 0010: Module split via internal CALL inside one transaction

## Status

Accepted. Go for the PR-05–09 splits (see "Go / no-go" below).

## Context

The PR-05–09 splits (card, deposit, wallet, auth, loan) move paragraphs out
of monolithic modules (1.693–2.452 lines) into new posting/session modules.
Two mechanisms were available:

1. **Internal CALL** (chosen): the owner module keeps the action dispatch
   entry and the transaction, and CALLs the new module for the extracted
   paragraphs inside its open transaction.
2. **Exact-action dispatch split** (fallback): new `D-PREFIX` entries route
   specific actions (e.g. `CARD_CAPTURE`) to the new module. Each action then
   owns its own transaction; nothing is shared.

The choice hinges on one bridge behavior (`cobol/src/sql_bridge.c`):
`SQL_BEGIN` while a transaction is already open (`G_CONN != NULL`) rolls
the open transaction back and starts a new one — it never nests. A callee
that issues `SQL_BEGIN` therefore destroys the caller's partial work, and a
callee `SQL_COMMIT` commits the caller's partial work early. The per-file
`check_transaction_ownership.mjs` gate cannot see this: it only checks that
each file balances BEGIN against COMMIT/ROLLBACK, not what happens across a
CALL edge.

## Decision

**One transaction, one owner, zero-transaction callees.** For every split:

1. The owner module keeps the dispatch entry, issues the single
   `SQL_BEGIN`, and issues the single `SQL_COMMIT`/`SQL_ROLLBACK` pair.
2. The extracted module contains **zero** `SQL_BEGIN`/`SQL_COMMIT`/
   `SQL_ROLLBACK` statements. Its SQL runs on the shared `G_CONN`, so it
   joins the owner's transaction: a callee failure rolls everything back
   with the owner's `SQL_ROLLBACK`, and a callee success commits atomically
   with the owner's `SQL_COMMIT`.
3. Every new `from -> to` edge is recorded in `manifest/cobol_calls.json`
   and reviewed (`check_cobol_call_graph.mjs` fails unlisted edges; the
   graph must stay acyclic).
4. `check_transaction_ownership.mjs` must show the extracted module at
   0/0/0 (no opens, no closes) and the owner balanced.
5. The move is proven with `git diff --color-moved` (paragraphs relocated,
   not rewritten) plus the action's existing DB/race/conservation suites.

Error propagation follows the existing convention: the callee returns its
result through the `WS-CALL-OUT` buffer, the caller checks `WS-CALL-OUT(1:5)`
for `"ERROR"` and fails its transaction on any error — the same shape as
the `card_core` → `gl_core` callsites.
