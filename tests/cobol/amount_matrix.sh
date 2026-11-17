#!/usr/bin/env bash
# PARSE-AMOUNT unit matrix (numeric hardening, DOT convention).
#
# Compiles a throwaway driver against cobol/copy/common_amount.cpy and
# feeds it decimal vectors through stdin, asserting the parsed major
# units (AMT-NUM) and the fail-closed flag (AMT-BAD). Covers what the
# gateway/DB suites cannot: comma tolerance, mixed/thousands rejection,
# TEST-NUMVAL rejects, and ON SIZE ERROR overflow.
#
# Driver I/O protocol (one result line per vector, sentinel "END." stops):
#   in:  raw amount text (may be empty)
#   out: "<trimmed AMT-NUM, 4dp>|<AMT-BAD>"  (e.g. "100.0000|0")
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

T_PASS=0; T_FAIL=0; T_TOTAL=0

command -v cobc >/dev/null 2>&1 || {
    echo "SKIP: amount matrix needs cobc"
    exit 0
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/amount-matrix.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/driver.cob" <<'COB'
       >>SOURCE FORMAT IS FREE
       IDENTIFICATION DIVISION.
       PROGRAM-ID. amount_driver.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  AMT-SRC                PIC X(100) VALUE SPACES.
       01  AMT-BUF                PIC X(100) VALUE SPACES.
       01  AMT-NUM                PIC S9(16)V9(4) VALUE 0.
       01  AMT-BAD                PIC 9 VALUE 0.
           88  AMT-OK             VALUE 0.
           88  AMT-BAD-FLAG       VALUE 1.
       01  AMT-TEXT               PIC -(15)9.9999 VALUE ZERO.
       01  WS-LINE                PIC X(100) VALUE SPACES.
       01  WS-DONE                PIC X VALUE 'N'.
       PROCEDURE DIVISION.
       MAIN-LOOP.
           PERFORM UNTIL WS-DONE = 'Y'
               MOVE SPACES TO WS-LINE
               ACCEPT WS-LINE END-ACCEPT
               IF WS-LINE(1:4) = "END."
                   MOVE 'Y' TO WS-DONE
               ELSE
                   MOVE WS-LINE TO AMT-SRC
                   PERFORM PARSE-AMOUNT
                   MOVE AMT-NUM TO AMT-TEXT
                   DISPLAY FUNCTION TRIM(AMT-TEXT) "|" AMT-BAD
               END-IF
           END-PERFORM.
           GOBACK.
       COPY "common_amount.cpy".
       END PROGRAM amount_driver.
COB

cobc -free -x -I "$ROOT/cobol/copy" -o "$WORK/driver" "$WORK/driver.cob" || {
    echo "FAIL: amount driver did not compile"
    exit 1
}

# Feed every vector in one process, then assert line by line.
mapfile -t ACTUAL < <(printf '%s\n' \
    '100.00' \
    '100,00' \
    '100' \
    '0.0001' \
    '9999999999999.9999' \
    '99999999999999999.99' \
    '12.34.56' \
    '1,000.00' \
    'ABC' \
    '' \
    '-5.00' \
    '0' \
    '5.00001' \
    'END.' \
    | "$WORK/driver")

expect() {
    # $1 = index, $2 = label, $3 = regex
    assert_match "$2" "${ACTUAL[$1]:-<no output>}" "$3"
}

expect 0  'dot decimal parses'          '^100\.0000\|0$'
expect 1  'comma decimal tolerated'     '^100\.0000\|0$'
expect 2  'integer parses'              '^100\.0000\|0$'
expect 3  'four-fraction-digit parses'  '^0\.0001\|0$'
expect 4  'max-width parses'            '\|0$'
expect 5  'overflow fails closed'       '^0\.0000\|1$'
expect 6  'double dot rejected'         '^0\.0000\|1$'
expect 7  'thousands form rejected'     '^0\.0000\|1$'
expect 8  'alpha rejected'              '^0\.0000\|1$'
expect 9  'empty rejected'              '^0\.0000\|1$'
expect 10 'sign accepted, caller range-checks' '^-5\.0000\|0$'
expect 11 'zero parses'                 '^0\.0000\|0$'
expect 12 'fifth fraction digit truncates to 4dp' '^5\.0000\|0$'

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
