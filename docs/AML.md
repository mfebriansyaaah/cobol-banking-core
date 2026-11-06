# AML / Sanctions Screening (PR-090)

## What it is (and is not)

- Baseline PEP/sanctions signal from OpenSanctions data (self-hosted yente
  for demo, non-commercial) with an OFAC/UN/EU list fallback. It is a
  **triage signal**, not a verdict: only a human reviewer confirms a match.
- Never claim "OFAC certified" or equivalent. Commercial use of
  OpenSanctions data needs a license (`SCREENING_LICENSE=commercial` +
  `SCREENING_LICENSE_KEY`; otherwise the adapter refuses).

## Data sent

- Name + birth year only, with per-call consent. The query hash (SHA-256)
  is stored for audit; the raw name is never logged or persisted.
- NIK never leaves the process for screening.

## State machine

- Adapter: `CLEAR` (no match) / `POTENTIAL_MATCH` (any match) /
  `MANUAL_REVIEW` (provider down, malformed, timeout — fail-closed, never
  `CLEAR` on doubt) / `SKIPPED` (no consent/endpoint — not recorded).
- COBOL (`SCR_SCREEN`): middleware verdicts record owner-side; reviewer
  verdicts (`FALSE_POSITIVE`, `CONFIRMED_MATCH`) need `SUPER_ADMIN`, so a
  potential match is never auto-cleared. Non-clear results open a
  `SCREENING` review row in the same transaction.
- KYC gate (`IDV_APPLY`): approval needs latest verdict `CLEAR` or reviewed
  `FALSE_POSITIVE`; otherwise `KYC_PENDING|SCREENING`. Approval is sticky:
  post-approval adverse info goes to review + suspension, not silent
  un-approval.
- Reviews: `GET /screening/reviews` (kind-filtered list),
  `POST /screening/reviews/decide` (shared `IDV_REVIEW_DECIDE`), both
  step-up authed.
