# FX rounding, fee reversal, and rate validity

Status: accepted
Date: 2026-10-18
Phase: Gate 1 / Gate 0 boundary.

## Context

The accounting audit (Oct 2026) found three policy questions the code cannot
answer on its own. Each has a current behavior that is internally consistent
but unratified. Changing any of them moves money or changes accounting
records, so each needs an accountable owner (compliance + finance; security
where noted). This ADR is a draft: it records the options and their
implications and is accepted only when an owner signs off below.

None of these may be hardcoded. Whichever option is chosen must live in
owner-controlled data or configuration, with tests, per
`CODING_STANDARDS.md`.

## D1 — FX rounding and the debit/credit value gap

**Current behavior.** For a cross-currency transfer, the sender is debited
`ROUND(amount, sender_prec)` and the target is credited
`ROUND(amount * rate, target_prec)`; the two legs are rounded independently
and no account records the difference.

**Evidence.** 1.01 USD → GBP at a stored rate of 0.79 posts a debit of
1.0100 USD and a credit of 0.8000 GBP (the exact value is 0.7979). The
credited value differs from the debited value by roughly 0.0021 GBP and that
residual is unbooked. The same effect exists in the inverse direction.

**Options.**
- **A — Book the residual.** Keep per-leg rounding to currency precision and
  post the residual to a bank-owned FX gain/loss account (a new
  `account_type` or a designated account), inside the same transaction.
- **B — Keep and document.** Keep the current behavior and record the residual
  as immaterial and unbooked, with a stated materiality threshold.
- **C — Round to a policy number of minor units and treat the remainder as
  revenue** (a fee leg), making the rounding rule explicit and customer-visible.

**Implications.** A: extra posting leg + balanced-leg verification + a new
account type (schema) + rounding tests. B: documentation only, but the
rounding rule stays undefined. C: fee semantics, disclosure text, and a fee
leg on every cross-currency posting.

**Blocked:** `B-P0-PRECISION` "defined rounding".

## D2 — Fee refund on reversal

**Current behavior.** A reversal refunds the principal; a fee posted by the
original transfer stays in the bank's `FEE_INCOME` account. The reversal posts
only the two principal legs.

**Evidence.** Reversing a 10.00 transfer that carried a 0.50 fee returns
10.00 to the sender; `FEE_INCOME` keeps 0.50; the ledger shows the `Fee out` /
`Fee in` legs unreversed.

**Options.**
- **A — Keep the fee.** A reversal corrects the principal only; fees are
  retained.
- **B — Refund the fee.** The reversal also posts a compensating `FEE` journal
  (bank → sender) and its own balanced-leg verification.
- **C — Refund by reason.** Refund the fee for bank-error reversals, retain it
  otherwise; the reversal carries a reason code that selects the policy.

**Implications.** A: none (status quo), but state it in customer terms.
B: two extra legs + verification + tests. C: a reason code on the reversal
request, a policy table, and tests per reason.

**Blocked:** `B-P1-LIFECYCLE` "fees ... failed/reversed/returned" completeness.

## D3 — Exchange-rate validity window

**Current behavior.** `exchange_rates` has `updated_at`, but a transfer uses
whatever rate row is present regardless of age; a stale rate posts silently.

**Evidence.** No validity column and no age check in the transfer path.

**Options.**
- **A — Enforce a window.** Add a maximum age (owner-set) and refuse stale
  rates with a distinct error, failing the transfer closed.
- **B — Alert only.** Keep posting but raise an operational alert when a rate
  is older than the window.
- **C — Keep as-is.** Rates are owner-owned data refreshed out of band; no
  code-level check.

**Implications.** A: schema (a validity/updated threshold or a policy table),
a transfer-path check, a new error code + its HTTP status, and tests.
B: an alert signal in the scheduler/metrics, no posting change.
C: documentation only; the stale-rate risk stays open.

**Blocked:** `B-P0-PRECISION` "rate source/validity".

## Decision

Decided **2026-10-18** by **nineboll07 (owner)**. In a licensed entity the
named compliance/finance owners must ratify these before production (Gate 0).

```
D1: option A — nineboll07 (owner), 2026-10-18
D2: option C — nineboll07 (owner), 2026-10-18
D3: option A — nineboll07 (owner), 2026-10-18
```

- **D1 — option A: book the residual.** The sender is debited and the target
  credited at each currency's own precision; the value residual is posted,
  inside the same transaction, to a bank-owned FX gain/loss account. It is
  represented as a new `account_type` (FX_PNL), one active account per
  currency, mirroring `FEE_INCOME`. The residual for a posting goes to the
  target currency's FX P&L account.
- **D2 — option C: refund by reason.** A reversal carries a required reason
  (missing reason is `ERROR|INVALID_INPUT`). A policy table maps reason →
  refund (yes/no), seeded with `BANK_ERROR` (refund) and `CUSTOMER_ERROR`
  (retain); the policy lives in data, not code. A refund posts a compensating
  `FEE` journal (bank → sender) with its own balanced-leg verification.
- **D3 — option A: enforce a window, fail closed.** A maximum rate age
  (default 24 hours, configurable, not hardcoded) is enforced in the transfer
  path; a rate older than the window is rejected with a new
  `ERROR|RATE_STALE`, mapped to HTTP 409, distinct from `RATE_NOT_FOUND`.

Implementation is tracked as PR-C follow-ups; none of the three may be
hardcoded (each is owner-controlled data or configuration, with tests).

## Consequences

- The decisions are ratified; the current behavior stands until the
  implementation PR(s) land. `docs/TRACEABILITY.md` (`B-P0-PRECISION`,
  `B-P1-LIFECYCLE`) tracks the remaining implementation work.
- Each decision changes money or accounting records, so implementation lands
  as its own reviewed PR with tests; nothing is hardcoded.
