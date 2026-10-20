# Access review and attestation

Status: accepted
Date: 2026-10-20
Phase: Gate 2 (access control). Implements the "access reviews" leg of
requirement `A-P0-ACCESS` in `docs/TRACEABILITY.md`.

## Context

`A-P0-ACCESS` is recorded as `partial` with the explicit gap "no access
reviews". The system already enforces least privilege at runtime — a
`SUPER_ADMIN`/`MANAGER` hierarchy, a last-admin guard, dual control for
designated operations, step-up re-authentication for privileged writes, and
attributable audit rows — but nothing ever asks the bank to *look again* at
who holds those privileges. A role granted once stays granted until someone
notices by accident.

An access review is the periodic, evidenced re-attestation of privileged
accounts: someone other than the holder confirms that each privileged account
still needs its access, and revokes what does not. Regulators ask for the
review itself and for its outcome, not just for the controls around it.

## Decision

1. **A review is a point-in-time snapshot.** Opening a review copies every
   privileged account (`MANAGER`, `SUPER_ADMIN`) into review items with the
   role, account status, MFA state, and last sign-in captured at that moment.
   The item is evidence of what was true when the review opened; it is not a
   live view, and it does not follow later role changes.
2. **The reviewer is not the subject.** An item can only be decided by an
   actor other than the account it covers. Self-attestation is refused with
   `FORBIDDEN` and audited.
3. **Every item must be decided before the review closes.** A close is refused
   while any item is still `PENDING` (`REVIEW_INCOMPLETE`).
4. **A revocation must actually take effect.** An item decided `REVOKED` is a
   decision to remove the access, not the removal itself. The review cannot
   close while a revoked subject still holds a privileged role in a verified
   state (`REVOCATION_PENDING`). Removal is performed through the existing
   privileged actions (`SET_USER_STATUS`, `CHANGE_ROLE`), so it keeps its
   rank check, its last-admin guard, its maker-checker designation, and its
   step-up requirement.
5. **One open review at a time.** A second open review is refused
   (`REVIEW_ALREADY_OPEN`), so there is exactly one live attestation to act on.
6. **Everything is auditable.** Opening, deciding, and closing write audit
   rows with the actor; the review, its items, and their decisions are
   retained as evidence.

## Why the removal is not automatic

Executing the revocation inside the review would bypass the controls that
make revocation safe: the rank hierarchy, the last-admin protection, and the
maker-checker designation for role changes. Keeping the decision and the
execution separate means the review records the decision while the existing
privileged path records the change, with its own audit row, its own guards,
and its own approvals.

## Consequences

- A new `access_reviews` / `access_review_items` pair and a `users.last_login_at`
  column, owned by migration `0041`.
- Five COBOL actions in `cobol/src/auth_core.cob` (`OPEN_ACCESS_REVIEW`,
  `LIST_ACCESS_REVIEWS`, `GET_ACCESS_REVIEW`, `DECIDE_ACCESS_ITEM`,
  `CLOSE_ACCESS_REVIEW`) and their gateway routes. Business rules stay in
  COBOL; the gateway only validates shapes and maps the result.
- `last_login_at` is written on a successful login so a reviewer can see how
  long a privileged account has been dormant.
- `A-P0-ACCESS` remains `partial` in `docs/TRACEABILITY.md`: the review
  mechanism is implemented and tested, but the review cadence, the accountable
  owner, and the evidence retention period are Gate 0 decisions
  (`docs/GATE0_DECISIONS.md` items 2 and 14) and are not assumed here.
