# ADR 0009: Module-extraction playbook (resolve / JOIN / passthrough)

## Status

Accepted. Companion to ADR-0010 (which fixes the transaction-ownership
half); this records the *shaping* half learned across the Wave-C splits
(PR-05–PR-09, each proven by `git diff --color-moved` relocation plus the
domain DB/race/conservation suites).

## Context

ADR-0010 requires zero-transaction callees, but it does not say where
the paragraph boundary goes or how state crosses the internal CALL.
The CALL carries exactly 8 slots (`LS-CMD-ACTION`, `LS-PARAM1..6`,
`LS-OUTPUT-BUFFER`) — no working storage crosses. That single constraint
selects the shape:

## Decision

Pick the narrowest shape whose inputs fit the 8 slots:

1. **Resolve-split** (card/deposit/loan posting): the callee owns the
   pre-transaction resolve + GL post and returns fixed-width fields
   (`SUCCESS|POST_READY|<9 pipe fields>`); the caller UNSTRINGs them
   into its own working storage and runs the money transaction.
   Use when the resolve is separable from the writes.
2. **JOIN** (wallet transfer engine, revoke-all-sessions): the whole
   engine moves and the callee's SQL joins the owner's transaction;
   the caller only opens/closes and moves the final buffer verbatim.
   Use when the body is one atomic unit whose working storage cannot
   cross the CALL (e.g. the transfer's ~20 flags/accumulators).
3. **Passthrough** (auth sessions): autocommit paragraphs move and the
   caller forwards the callee's buffer verbatim (`MOVE WS-CALL-OUT TO
   LS-OUTPUT-BUFFER`). Use when there is no owner-side transaction and
   no post-processing. Auth guards stay owner-side and run before the
   CALL (hoisted, not duplicated — the callee trusts pre-authorized
   input, documented at each call site).

Errors use `ERROR|<CODE>|<CLEANUP 0/1>`: on `CLEANUP=1` the owner of
the DELETE-* paragraph runs it (caller-side for card, callee-side where
the plan moved the helpers), then reproduces the exact output mapping,
GL verbatim passthrough included. Idempotency `DONE` replays bypass
field protocols and return `SUCCESS|...` verbatim.

Hard rules, each bought with a real bug:

- Caller-side numerics never cross the CALL. `NUMVAL`, `TRIM` lengths,
  and normalized amounts are recomputed deterministically inside the
  callee (PR-05's missing P4 amount, PR-09's zeroed `WS-NUM-AMOUNT`).
- The callee entry re-trims and re-validates with byte-identical
  semantics; pre-trimmed inputs make this idempotent, not redundant.
- `DECIMAL-POINT` must match the owner (`COMMA` for wallet/auth:
  `PARSE-MAJOR` and `COMPUTE NUMVAL` depend on it).
- Never `CALL` back into the owner (acyclic graph, enforced by
  `check_cobol_call_graph`); never duplicate a paragraph across the
  seam (move it, or hoist its callers, or share via `cobol/copy/`).

## Consequences

- Future splits start from the decision tree above instead of
  rediscovering the constraints; deviations (e.g. a state that cannot
  cross 8 slots) must be argued in the PR, not silently worked around
  with pipe-packing or duplication.
- Reviewers verify: paragraph moved verbatim except the enumerated
  adaptations (txn statements, guard hoists, OUT-protocol lines),
  0/0/0 transaction standing on the callee, and the action's suites
  green without new assertions papering over behavior change.
