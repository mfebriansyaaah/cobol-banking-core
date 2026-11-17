# ADR 0013: Idempotency generalization complete (thin wrappers remain)

## Status

Accepted (DRY-07 closure assessment, Nov 2026). The generalization the
plan asked for is done; what remains is thin domain staging that sits at
the practical floor of what COBOL can share. No further extraction is
planned.

## Context

ADR-0008 fixed the claim/replay/takeover protocol. PR-14A (commit
2e6890e3) built the unified `idempotency_request` table (migration
0687) and `common_idem.cpy` (777 lines: `IDEM-RESET/CLAIM/COMPLETE/
DELETE`, mirror sync, scope resolution, DETAILS/journal variants);
PR-14B (commit 44514714) migrated card (3 pairs), deposit settle,
collection pay, deposit-posting settle, payment-clearing settle, and
loan-posting disburse+repay onto it with dual-write (legacy rows stay
the decision-makers; the mirror follows every transition and fails
closed). All ten legacy request tables dual-write; none was dropped,
per ADR-0008.

## What the engine migration left behind

14 thin `CLAIM-*`/`DELETE-*` wrapper paragraphs, 163 lines total. A
typical one stages 6–7 fields into `WS-IDEM-*` slots and performs one
shared paragraph (e.g. card `CLAIM-CAPTURE-REQUEST`: RESET + scope/
entity/key/amount/details/code + `IDEM-CLAIM`). The engine — 70-line
`IDEM-CLAIM` included — is fully shared.

Collapsing the wrappers would require passing the field mapping as
data. COBOL offers two mechanisms and both are out: `COPY REPLACING`
with `== ==` tokens does not compile on GnuCOBOL 3.2.0 and would blind
every source-level gate (ADR-0012); a C-bridge subprogram with N
arguments would move business logic into the SQL-execution layer and
create a new ABI surface in money paths. Saving at most ~100 lines is
not worth either. The wrappers stay.

## Deliberately out of scope

- **Wallet `pending_transactions`.** The transfer engine
  (`wallet_transfer_core`, maint-07/ADR-0010) implements
  first-writer-wins + conflict with EOD purge and no 5-minute takeover.
  Migrating it onto `common_idem` would *change* its semantics
  (takeover/replay where none exist) — a product decision with its own
  proof burden, not a refactor. Untouched on purpose.
- **Ledger/journal/balance primitives.** The remaining writes are
  domain-parameterized (descriptions, amount sources, account
  resolution differ per action); the SQL-EXEC wrapper rollout (waves
  13h–13hc) already shrank every CALL site to one line. Same verdict
  as the wrappers: at the floor.
- **Dropping the legacy tables.** Forbidden by ADR-0008 for the
  migration PRs and not re-proposed here: dual-write stays.

## Acceptance (continuous, not a one-time gate)

- No double posting, identical outputs: the race, conservation, and
  idempotency DB suites (58 suites across the shard fleet) plus the
  money-path mutants (M2 neuters both idempotency flags) run on every
  CI pass over `main`. They are green.
- The per-module coverage ratchet, the copybooks-union ratchet
  (shared paragraphs are highest-leverage), and the duplication
  baseline all bind the shared engine against silent rot.

## Consequences

- DRY-07 is closed. Future idempotency work is either product work
  (wallet migration, table drops — each its own proposal with DB
  proofs) or engine hardening, not deduplication.
- New money actions reuse the pattern: stage `WS-IDEM-*`, perform the
  shared paragraph, never inline the protocol. `docs/MODULE_AUTHORING.md`
  owns the recipe; this ADR owns the why.
