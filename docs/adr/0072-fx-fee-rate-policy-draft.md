# FX rounding, fee reversal, and rate validity (owner decision)

Status: **proposed — awaiting owner decision**
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

_Not made._ For each of D1, D2, D3 record the chosen option here with the
accountable owner and date, e.g.:

```
D1: option ? — approved by <compliance>, <finance> on <date>
D2: option ? — approved by <compliance>, <finance> on <date>
D3: option ? — approved by <compliance>, <ops> on <date>
```

Then open the implementation PR(s); the change must not hardcode the policy.

## Consequences

- Until decided, the current behavior stands and is recorded as an unratified
  policy gap in `docs/TRACEABILITY.md` (`B-P0-PRECISION`, `B-P1-LIFECYCLE`).
- No implementation is safe to guess: each option changes money or accounting
  records and needs the owner's sign-off above.
