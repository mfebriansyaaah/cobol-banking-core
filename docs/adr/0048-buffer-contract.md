# Machine-checked C/COBOL buffer contract

Status: accepted
Date: 2026-10-17
Phase: Core bridge & C-libraries audit (FASE D).

## Context

The FASE A fixes removed two live overflows, but the underlying rule — every
C bound must fit the COBOL field it touches — lived only in reviewers' heads.
A future field shrink (or a new C write) would silently reopen a
past-the-field write with no check to catch it.

## Decision

- Write the contract down in `docs/BUFFER_CONTRACT.md`: every C
  read/write bound beside the COBOL field(s) it touches, with sizes and the
  reason each fits (including the non-obvious ones, e.g. `SET_QUERY` 511 is
  correct for the 512-byte `WS-QUERY`).
- Enforce both sides in CI: `tests/buffer_contract_check.sh` pins every
  COBOL field size (failing on any shrink below the C bound, verified
  against a deliberately shrunk copy), while `tests/test_c_memory.sh`
  (ASan) pins the C writes. The new check runs as its own `ci.sh` step; it
  reports no assertion counts, so the baseline manifest is untouched.
- Reference the contract from `docs/STATUS.md` so the snapshot states the
  enforcement, not just the numbers.

## Consequences

- Shrinking a COBOL field or adding an oversized C write fails CI loudly on
  the exact field, instead of relying on review memory.
- No count changes (shell 614, gateway 104, full run 718 assertions).
