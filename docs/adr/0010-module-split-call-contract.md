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

## Evidence (production precedent)

The pattern is already live; the splits copy it, they do not invent it:

- `wallet_core` CHECK-PAYMENT-POLICY CALLs `payment_core` (`PAY_ENFORCE`,
  `ACTION-ENFORCE`, 0 transaction statements) for the limit verdict.
- `wallet_core` RECORD-VELOCITY-USAGE CALLs `fee_core`
  (`VEL_RECORD_ALL_TXN`, `ACTION-VEL-RECORD-ALL-TXN`, 0 transaction
  statements). The paragraph comment states the join explicitly: "The
  recorder joins this transaction (no BEGIN/COMMIT of its own), so a record
  failure rolls the money back with it instead of leaving counters behind
  the ledger."
- Both calls execute inside `TRANSFER-LOGIC` after its `SQL_BEGIN`
  (`wallet_core.cob:1207`) and before its `SQL_COMMIT`/`SQL_ROLLBACK`.
- Every transfer test therefore exercises the join: velocity records commit
  and roll back together with the ledger. The wallet conservation,
  concurrency, and race suites are the runtime proof.
- `scripts/test/module_split_contract.test.mjs` pins all of the above: both
  callee paragraphs at zero transaction statements, both CALL sites, both
  registry edges, and the bridge's leaked-transaction rollback rule.

Counter-example that stays out: `card_core` → `gl_core`
(`GL_JOURNAL_POST_ML`) is a separate-transaction call — `gl_core` opens and
commits its own transaction, and the call happens outside any open card
transaction. That shape is correct for journal pre-posting but is NOT the
split pattern: split callees must never open their own transaction.

## Go / no-go

**GO.** The bridge semantics, the gate coverage (`check_transaction_ownership`,
`check_cobol_call_graph`, the new contract pins), and the live
wallet → fee/payment precedent answer every exit criterion in the master
plan §3.8:

- Atomicity proof: single `G_CONN`, single `START TRANSACTION`, caller-owned
  close. A caller `SQL_ROLLBACK` undoes callee writes — the same guarantee
  the velocity-join comment already relies on.
- Call graph: new edges recorded in `manifest/cobol_calls.json`, acyclicity
  enforced.
- PR-05–09 may start. Each split records its edge, shows 0/0/0 on the new
  module, and proves the move with `git diff --color-moved` plus the
  action's DB/race/conservation suites.

## Fallback (not needed)

If a future split cannot keep the callee transaction-free (e.g. it must be
invoked standalone as well as joined), use exact-action dispatch: add a
`D-PREFIX` entry routing that action to the new module, which then owns its
own balanced transaction. Cost: two transactions instead of one (no atomicity
across them) plus dispatch-table review. This fallback was evaluated and
rejected for PR-05–09 because every extracted paragraph is only ever invoked
from inside its owner's transaction.
