# Maker-checker for designated operations (Gate 2)

Status: accepted
Date: 2026-10-17
Phase: Gate 2 — production controls (partial).

## Context

`PRD_Enterprise.md` section 4.A requires maker-checker/dual control for
designated privileged operations. Which operations, and with what quorum,
is an owner decision (Gate 0, still BLOCKED), so the repo must not
hardcode a list. The mechanism has to work without inventing policy.

## Decision

- `dual_control_operations` (migration 0033) is the bank-owned
  designation list, empty by default: nothing changes until the
  accountable owner designates operations. `maker_requests` holds one row
  per proposed change (`PENDING` → `APPROVED`/`REJECTED`).
- New COBOL actions: `REQUEST_OPERATION` (maker proposes; only designated
  operations), `APPROVE_REQUEST` (a different SUPER_ADMIN re-validates
  everything and executes in the same transaction — no approved-but-
  unexecuted state), `REJECT_REQUEST`, `LIST_REQUESTS` (paged, optional
  status filter). Self-approval is `FORBIDDEN`; stale conditions
  (demoted target, last-admin) fail the approval, leaving it `PENDING`.
- A designated operation refuses direct execution with
  `DUAL_CONTROL_REQUIRED` (HTTP 403): the bypass path is closed, not just
  undocumented. `CHANGE_ROLE` is the first gated operation and the Prove
  it works end to end; gating further operations is one hook plus tests.
- Gateway: `POST /admin/requests`, `/admin/requests/approve`,
  `/admin/requests/reject` (step-up), `GET /admin/requests`.
- Deliberately out of scope: multi-checker quorums (single checker only),
  request expiry, and the designation list itself (owner decision).

## Consequences

- A-P0-ACCESS stays partial: the mechanism is proven for one operation
  with the designation empty by default; enabling it is an explicit,
  auditable owner action (insert a row), not a code deploy.
- `tests/test_dual_control.sh` (29 checks) covers the lifecycle,
  bypass refusal, re-validation, and last-admin through approval.
