# ADR 0083 — Modular COBOL Core (incremental split of large domains)

Status: accepted
Date: 2026-10-24

## Context
`auth_core.cob` (235 KB) and `wallet_core.cob` (213 KB) are monoliths. A single
change in one capability (e.g. MFA recovery) forces recompiling and re-testing
the whole domain, and review diffs are large. `main_logic.cob` already acts as a
thin router, so the split can be done without changing the external contract
(CMD-ACTION strings, params, output buffer).

## Decision
Split each large core into sub-programs **by capability**, keeping the same
linkage section (`LS-CMD-ACTION`, `LS-PARAM1..6`, `LS-OUTPUT-BUFFER`) and the
same router dispatch. The router maps an action to the sub-program that owns it;
shared helpers move to a copybook (`cobol/copy/shared_core.cpy`) included by
each sub-program.

## Proposed split
auth_core.cob ->
  auth_login_core.cob       (AUTH_LOGIN, VERIFY_REAUTH, MFA_*, CHECK_ROLE)
  auth_session_core.cob     (STORE/REVOKE/CONSUME_SESSION, LIST_SESSIONS, REVOKE_*)
  auth_password_core.cob    (FORGOT/RESET/CHANGE_PASSWORD, password history)
  auth_audit_core.cob       (ARCHIVE_AUDIT, LIST_AUDIT, access review)
  auth_outbox_core.cob      (OUTBOX_*, LIST_OUTBOX)
  auth_mfa_recovery_core.cob (REQUEST/VERIFY/APPROVE/REJECT/LIST_MFA_RECOVERY)
  auth_admin_core.cob       (CHANGE_ROLE, REQUEST/APPROVE/REJECT_OPERATION, ...)

wallet_core.cob ->
  wallet_transfer_core.cob  (TRANSFER, limits, reversal)
  wallet_balance_core.cob   (CHECK_BALANCE, statements)
  wallet_hold_core.cob      (holds, fees)
  wallet_fx_core.cob        (FX conversion, pnl)

## Phases
1. Create sub-program skeletons with identical linkage and a no-op dispatch that
   CALLs back into the monolith (facade). Compile + smoke test.
2. Move one capability at a time; update router dispatch; run the affected suite.
3. Remove the moved paragraphs from the monolith once the sub-program is green.
4. Add per-sub-program tests (reuse existing suites, no new boilerplate).

## Consequences
- Positive: smaller diffs, targeted recompilation, easier unit testing, lower
  blast radius.
- Negative: more files, copybook dependency, one-time migration cost.
- Risk: linkage drift between sub-programs. Mitigated by a shared copybook and
  the existing contract tests (gateway + shell).

## Alternatives considered
- Keep monoliths and only add tests: rejected, does not reduce review/maintenance cost.
- Rewrite in another language: out of scope; COBOL is the domain core.
