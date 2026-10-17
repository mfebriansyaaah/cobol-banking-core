# Requirement traceability as a merge gate (Gate 0)

Status: accepted
Date: 2026-10-17
Phase: Gate 0 — product/regulatory definition.

## Context

`PRD_Enterprise.md` section 3, item 3 requires a
requirements-to-control-to-test-to-evidence traceability matrix: every
applicable obligation needs an owner, implementation, test/evidence,
retention period, and approval record, reassessed on every scope change.
Until the jurisdiction and accountable owners are named, compliance
features are requirements to resolve, not claims a generic implementation
satisfies a law. No machine enforced any of this; gaps were prose in
`docs/STATUS.md` and drifted (e.g. `SPEC-wallet-core.md` still claimed no
prepared statements long after the transfer path used them).

## Decision

- The matrix lives in `docs/TRACEABILITY.md`: one row per PRD P0/P1
  requirement plus the Gate 0 prerequisites, each with status
  (`implemented`/`partial`/`missing`), control, tests/evidence, owner,
  retention/approval, and gate. P2 requirements stay out until P0/P1
  controls land.
- `tests/traceability_check.sh` enforces it: every requirement ID appears
  exactly once; row shape and vocabulary are fixed; `implemented` rows must
  cite test evidence; `missing` rows must name their blocker; owner and
  retention cells must be non-empty. Every row is `UNASSIGNED` until Gate 0
  names accountable owners, so no row can read as a compliance claim.
- The check runs inside the existing `ci.sh` status step (no step
  renumbering) and the matrix is covered by `tests/docs_check.sh` path
  validation, so dangling references fail the build.
- The matrix is a living document: each PR that changes controls, tests,
  or Gate 0 facts must update the affected rows in the same change.

## Consequences

- New requirements enter the repo as `missing` rows with explicit blockers
  instead of silent absences.
- Owner approval stays outstanding on every row; closing Gate 0 means
  naming owners and replacing `UNASSIGNED`, not flipping statuses.
