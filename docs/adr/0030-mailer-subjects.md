# Per-purpose email subject

Status: accepted
Date: 2026-10-16
Phase: Notification/Mailer hardening (FASE B).

## Context

`sendVerification` only changed the subject for `EMAIL_CHANGE`; `SIGNUP` and
`PASSWORD_RESET` both used "Verify your account", so a password-reset email
was mislabelled (hurting deliverability and user trust).

## Decision

- Add `verificationSubject(purpose)`:
  - `EMAIL_CHANGE` -> "Confirm your new email address",
  - `PASSWORD_RESET` -> "Reset your password",
  - otherwise -> "Verify your account".
- `sendVerification` uses it (the code body is unchanged).

## Consequences

- Each flow's email is labelled correctly, which helps users and spam filters.
- The mapping is a small pure function, unit-tested directly.
