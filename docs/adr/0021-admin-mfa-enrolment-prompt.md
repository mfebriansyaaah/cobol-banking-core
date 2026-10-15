# Prompt administrators to enrol MFA at login

Status: accepted
Date: 2026-10-15
Phase: Admin/Governance hardening (FASE I).

## Context

ADR 0020 mandated MFA for admin step-up, but there was no signal at login: an
administrator would only discover the requirement when a privileged write was
refused. The client had no way to know it should prompt enrolment.

## Decision

- Add `GET_MFA_STATE(email)` (auth_core): returns `role|mfa_enabled` (e.g.
  `SUCCESS|SUPER_ADMIN|0`).
- `POST /auth/login` and `POST /auth/refresh` call it and, when the account is a
  `SUPER_ADMIN`/`MANAGER` without MFA, include `mfaEnrollmentRequired: true` in
  the JSON response. The access token is unchanged (not a limited token):
  login and enrolment remain fully usable, and the hard block stays on the
  privileged writes (the step-up gate of ADR 0019/0020).
- The client uses the flag to route the admin into enrolment
  (`POST /mfa/enroll` + `/mfa/confirm`); a subsequent login/refresh reports the
  flag as false once MFA is enabled.

## Consequences

- An administrator is told at login that MFA enrolment is required, instead of
  only hitting `MFA_SETUP_REQUIRED` later.
- The access token is not restricted, so nothing else about a logged-in
  administrator changes; the mandate remains enforced where it matters
  (privileged writes).
- `GET_MFA_STATE` is a small read used by the gateway; covered by
  `tests/test_mfa_state.sh` and a gateway test that enrols and confirms the flag
  clears.
