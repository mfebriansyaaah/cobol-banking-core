# Risk-based step-up for customer actions

Status: accepted
Date: 2026-10-20
Phase: Gate 2 (access control). Extends the step-up control in ADR 0019.

## Context

Step-up re-authentication (`VERIFY_REAUTH` plus a short-lived proof) is already
required for privileged admin writes. Customer actions that move money or
change the credentials of an account have no such check: a stolen but still
valid access token can change the account email, disable MFA, or move funds
until the risk is noticed.

Requiring a proof for every action would be unusable. The requirement should
be data-driven and risk-based.

## Decision

1. **The requirement is owner-controlled data.** `step_up_policy` maps a
   catalogued action to `enabled` and a `min_amount`. The seed is
   conservative:
   - `REQ_EMAIL_CHANGE`: required always;
   - `MFA_DISABLE`: required always;
   - `TRANSFER`: **disabled** until the owner sets a threshold (enabling it
     with a zero minimum would interrupt every transfer).
2. **COBOL decides.** `STEP_UP_REQUIRED` takes the actor email, the action,
   and an optional amount, and answers `STEP_UP_REQUIRED` or
   `STEP_UP_NOT_REQUIRED` from the policy row. The gateway never reimplements
   the rule; it only forwards the answer and, when required, verifies the
   `X-Step-Up` proof minted by `POST /auth/step-up`.
3. **The comparison is exact.** The amount is compared as a decimal by the
   database against `min_amount`; the gateway validates the amount format
   before invoking, and the core treats an absent amount as zero. A policy
   read error fails closed (`STEP_UP_POLICY_FAILED`, HTTP 500) rather than
   silently allowing the action.
4. **The gateway enforces at the routes that carry the risk**: email change,
   MFA disable, and transfer. The static admin step-up stays as it is; an
   action can use one or the other, never both.

## Consequences

- Migration `0045`: `step_up_policy`, seeded as above, folded into the schema
  baseline.
- A COBOL action (`STEP_UP_REQUIRED`) and a gateway middleware
  (`requireStepUpPolicy`) that reuses the existing proof verification.
- Email-change and MFA-disable requests now need a step-up proof; the tests
  and the endpoint smoke suite obtain one. Transfers keep working unchanged
  until an owner enables the policy with a threshold.
- The policy threshold is a risk-owner decision; the ADR records the
  mechanism, not an approved number.
