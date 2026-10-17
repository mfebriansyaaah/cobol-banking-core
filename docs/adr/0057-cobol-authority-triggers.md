# COBOL authority over business decisions; trigger exception

Status: accepted
Date: 2026-10-17
Phase: Regulated-bank charter enforcement (audit follow-up).

## Context

The regulated-bank charter (rule 21) makes COBOL the mandatory, sole
authority for business decisions and forbids reimplementing them in other
layers. An audit found two frictions against that rule:

1. The gateway decided the MFA-enrolment prompt itself (`needsEnroll` in
   `middleware/src/app.js` reimplemented the SUPER_ADMIN/MANAGER-without-MFA
   rule already enforced by COBOL `VERIFY_REAUTH`).
2. The database carries four triggers (`trg_audit_snapshot_user_delete`,
   `trg_audit_no_update`, `trg_ledger_no_update`,
   `trg_ledger_archive_account`) that look like non-COBOL logic.

## Decision

- **The enrolment decision moves to COBOL.** New action
  `MFA_ENROLL_REQUIRED(email)` returns `SUCCESS|1` for SUPER_ADMIN/MANAGER
  without MFA and `SUCCESS|0` otherwise; the gateway forwards the flag
  without reimplementing the role rule. The now-unused `GET_MFA_STATE`
  read action is removed (router, module, tests, docs) so the decision has
  exactly one implementation.
- **The four triggers stay, under an explicit, narrow exception.** They are
  database integrity constraints of last resort, not business decision
  makers: the two `*_no_update` triggers mirror `CHECK`-style immutability
  (append-only journal/audit), and the two archive triggers preserve evidence
  across cascaded deletes that no COBOL action performs (COBOL never deletes
  users or accounts; only deactivation/close flows exist). They encode no
  who/when/why policy — retention windows, authorization, and archival
  orchestration remain COBOL actions (`ARCHIVE_AUDIT`, explicit status
  changes). Any new trigger requires its own approved ADR; silent expansion
  of trigger logic is rejected by rule 21 as amended.
- **CI failure handling is explicit.** `ci.sh` captures each step’s exit code
  and fails loudly with it instead of relying on `set -e` aborts or
  `|| true` guards; counting uses an always-zero awk helper. Standard-output
  redirection of suite stderr is retained (parsers depend on clean stdout),
  but a non-zero exit now fails the step with its tail visible — concealment
  is removed, not the redirection.

## Consequences

- One authoritative implementation of the enrolment rule, covered by the
  `MFA_ENROLL_REQUIRED` decision table in `tests/test_mfa_state.sh` (5
  checks) plus the unchanged end-to-end gateway assertions on
  `mfaEnrollmentRequired`.
- Triggers remain purely defensive; reviewers treat any trigger encoding a
  business decision as a violation.
