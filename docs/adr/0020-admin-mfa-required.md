# Admin accounts must have MFA enabled

Status: accepted
Date: 2026-10-15
Phase: Admin/Governance hardening (FASE H).

## Context

ADR 0019 added step-up re-authentication for privileged admin writes, but MFA
was only required when the account already had it enabled: an admin without MFA
could step up with the password alone, so the second factor was effectively
optional for the most privileged accounts.

## Decision

- `VERIFY_REAUTH` (the step-up action) now fetches the account's role. When the
  role is `SUPER_ADMIN` or `MANAGER` **and** MFA is not enabled, it refuses with
  `ERROR|MFA_SETUP_REQUIRED` (HTTP 401).
- Consequently, an administrator must enable MFA before they can perform any
  privileged write (role change, status change, unlock, MFA reset, audit
  archive, transfer reversal). A non-admin (USER) still steps up with the
  password alone.
- Login and MFA enrolment are unaffected: an admin can still log in without MFA
  and enrol (`MFA_ENROLL_BEGIN`/`MFA_ENROLL_CONFIRM`), which is the intended
  bootstrap. Only the privileged actions are blocked until then.

## Consequences

- The most privileged accounts can no longer be operated with a single factor:
  a stolen password is not enough, and a stolen access token is not enough.
- An admin who loses their MFA device can be recovered by another admin
  (`ADMIN_RESET_MFA`), so the mandate does not create a hard lockout.
- Known gap: there is no forced-enrolment prompt at login, so an admin can be
  logged in without MFA but simply cannot perform privileged writes until they
  enrol. Covered by `tests/test_stepup.sh` and the admin step-up gateway tests.
