# FX rounding, fee reversal, and rate validity

Status: accepted
Date: 2026-10-18
Phase: Gate 1 / Gate 0 boundary.

## Context

The accounting audit (Oct 2026) found three policy questions the code cannot
answer on its own. Each has a behavior that moves money or changes accounting
records, so each needs an accountable owner (compliance + finance; security
where noted). The options and owner decisions are recorded below. Licensed-
entity compliance/finance ratification is still required before production.

None of these may be hardcoded. Whichever option is chosen must live in
owner-controlled data or configuration, with tests, per
`CODING_STANDARDS.md`.

## D1 — FX rounding and the debit/credit value gap

**Observed before implementation.** For a cross-currency transfer, the sender is debited
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

**Implementation.** PR #231 books the 4dp residual to the target currency's
FX_PNL account in the same journal; exact postings skip the extra leg.

## D2 — Fee refund on reversal

**Observed before implementation.** A reversal refunded the principal; a fee posted by the
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

**Implementation.** PR #230 requires a reversal reason and consults the
owner-controlled `reversal_fee_policy` table; `BANK_ERROR` refunds,
`CUSTOMER_ERROR` retains the fee, and the reason is recorded on the marker.

## D3 — Exchange-rate validity window

**Observed before implementation.** `exchange_rates` had `updated_at`, but a transfer used
whatever rate row is present regardless of age; a stale rate posts silently.

**Evidence at decision time.** No validity column and no age check in the
transfer path; PR #229 implements the selected control.

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

**Implementation.** PR #229 enforces `RATE_MAX_AGE_SECONDS` (default 24 hours)
in both direct and inverse lookup paths; stale rates fail closed with
`ERROR|RATE_STALE` (HTTP 409).

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

All three implementations are merged and tested. Their policies remain
owner-controlled; none is hardcoded. The licensed entity's named compliance
and finance owners must ratify the decisions before production.

## Consequences

- The implementations are merged in PRs #229-#231. `docs/TRACEABILITY.md`
  records their controls and tests; production ratification remains open at
  Gate 0.
- Each decision changes money or accounting records, so each implementation
  landed as its own reviewed PR with tests; none of the policies is hardcoded.
