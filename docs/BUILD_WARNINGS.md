# Build warnings and the warning ratchet

The COBOL build (`./build.sh`, `cobc -Wall -Wextra`) emits warnings on the
legacy codebase. `tests/warning_check.sh` freezes the per-class counts in
`tests/warning_baseline.txt` and CI (step 3, right after the build) fails when
a class grows, so new code cannot add warnings. Lower a baseline when warnings
are fixed; never raise one to accept new ones.

## Classes

### `-Wothers` — duplicate USING BY REFERENCE (1087)

The SQL bridge (`SQL_PREPARE_EXEC`, `SQL_PREPARE_EXEC_ROWS`, ...) has a
fixed-arity signature, so callers pad unused bind slots by passing the same
`WS-BIND-n` several times. The warning is the intended padding, not a bug.

### `-Wterminator` — missing scope terminators (1006)

`CALL`, `IF`, `COMPUTE`, `ADD`, `WRITE`, `ACCEPT`, `DISPLAY` without their
`END-…` terminator. `CODING_STANDARDS.md` rule 14 requires explicit
terminators in new code, and the ratchet enforces that (a new unterminated
statement raises the count and fails CI). The existing 1006 are frozen debt:
most are single-line `CALL` statements, and a bulk mechanical retrofit is high
churn for no behavioral gain, so it is paid down incrementally rather than in
one sweep.

### `-Wpossible-truncate` — reviewed benign (79)

All 79 were reviewed; none can lose data at the current bounds:

- **69 "sending field larger than receiving field".** Two shapes:
  - `MOVE WS-RESULT TO <scalar>`: `WS-RESULT` is `X(16384)` but every such
    query returns a single short value (an id, a status, a rate, a count, a
    formatted balance ≤ 23 chars, a PBKDF2 hash ≤ 256, a base32 secret ≤ 64).
    The destination field is sized for the value.
  - `MOVE WS-PARAMn-TRIMMED TO <field>`: the parameter is `X(100)` but the
    gateway/validator constrains the value (a date is exactly 10, a limit is
    a few digits, a trigger is `MANUAL`/`SCHEDULED`), and the destination is
    sized accordingly.
- **10 "some digits may be truncated".** `MOVE WS-I TO WS-*-LEN` where `WS-I`
  is `PIC 9(5)` and the length field is `PIC 9(3)`; the loop bounds `WS-I` at
  100, so it always fits.

If a change ever makes one of these values larger than its field, that is a
real defect — the review above is what makes them benign, and a new truncation
warning fails the ratchet.

## Using the ratchet

```sh
./tests/warning_check.sh            # builds, then checks
./tests/warning_check.sh build.log  # checks an existing log
```

To pay down debt: fix warnings, run the check, lower the matching number in
`tests/warning_baseline.txt`.
