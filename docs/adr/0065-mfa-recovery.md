# MFA backup codes and assisted recovery (Gate 2)

Status: accepted
Date: 2026-10-17
Phase: Gate 2 — production controls (partial).

## Context

`PRD_Enterprise.md` section 4.A requires secure customer and administrator
recovery including lost MFA devices, identity re-proofing, approval,
notification, and audit. Losing TOTP previously meant an admin-only reset
with no customer path, no approval, and no notification.

## Decision

- Single-use backup codes (`mfa_backup_codes`, migration 0035): 8 codes
  generated at enrolment-confirmation time, PBKDF2-hashed at rest, shown
  exactly once. A code works in place of TOTP at login and step-up only
  (never for enrol/disable), burns on use, and is cleared by disable,
  admin reset, approval, and regeneration. Verification reuses the
  password-KDF path (constant work, no oracle).
- Assisted recovery (`mfa_recovery_requests`): the owner proves identity
  twice — password (re-proofing part one, neutral on failure) plus an
  emailed code (part two, capped and burned like password resets). Only a
  `VERIFIED` request can be approved; approval clears MFA and backup
  codes, burns the code, sends a notice through the outbox, and audits.
  No self-approval; rejected requests are terminal and auditable.
- New COBOL actions: `MFA_BACKUP_CODES` (owner-only, MFA required),
  `REQUEST/VERIFY/APPROVE/REJECT_MFA_RECOVERY`, `LIST_MFA_RECOVERY`.
  Gateway: `POST /mfa/backup-codes`, `POST /mfa/recover`, `POST
  /mfa/recover/confirm`, `POST /admin/mfa-recovery/approve|reject`
  (step-up), `GET /admin/mfa-recovery`. The login/step-up `mfaCode`
  accepts 6-digit TOTP or 10-digit backup codes.
- Deliberately out of scope: hardware-key/WebAuthn factors, recovery
  SLAs/deadlines, and backup-code expiry.

## Consequences

- A-P1-RECOVERY is satisfied in code (owner approval outstanding on every
  row). `tests/test_mfa_recovery.sh` (38 checks) plus a gateway
  end-to-end test cover generation, use-once semantics, re-proofing,
  strict ordering, and notification.
- Losing the authenticator no longer strands the account, and no single
  party can reset MFA unattended.
