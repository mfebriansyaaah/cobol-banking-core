# C/COBOL memory-boundary safety

Status: accepted
Date: 2026-10-16
Phase: Core bridge & C-libraries audit (FASE A).

## Context

C functions receive COBOL fields as bare pointers with no size attached, so
every write relies on an unwritten contract. The audit found two live
off-by-one overflows: the password/TOTP verifiers wrote a 2-byte
NUL-terminated result into 1-byte `WS-VERIFY` fields, and the random-code
generator wrote 7 bytes (`%06d` plus terminator) into 6-byte `WS-RAND` — each
clobbering the first byte of the neighbouring field. Impact was benign in
practice (neighbours are rewritten before being read) but any reordering
would have turned them live. A third gap: the PBKDF2 cost parsed from a
stored hash was uncapped, so a corrupt row meant unbounded CPU burn.

## Decision

- Drop the terminator writes: the three verify functions now write only
  `result[0]` (every COBOL use is a single-char comparison; nothing reads a
  terminator).
- Size `WS-RAND` to X(7); all existing `(1:6)` references keep working.
- Refuse stored PBKDF2 costs above `PBKDF2_MAX_ITERATIONS` before burning CPU.
- Add `tests/test_c_memory.sh` (12 checks): an AddressSanitizer+UBSanitizer
  harness compiled against the real library sources proves 1-byte result
  writes, 6-digit codes, 32-char secrets and fast cost refusal. Verified to
  fail on the pre-fix sources (`stack-buffer-overflow, WRITE of size 1`).
- Also audited and left unchanged: every `strncpy` bound is at most its field
  size (`SET_QUERY` 511 is correct for the 512-byte `WS-QUERY`, not a bug),
  all 17 `SQL_BEGIN` sites reach COMMIT/ROLLBACK with no early exit, pool
  workers are SIGKILLed on timeout (server-side rollback), and NULL decodes
  to a rejected key.

## Consequences

- The C/COBOL size contract is now enforced by a sanitizer suite instead of
  eyeballing; future C changes that overrun a COBOL field fail CI.
- Shell 595 -> 607, gateway 104 unchanged; full run 711 assertions.
