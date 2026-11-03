#!/usr/bin/env bash
# Property-based / fuzz testing: malformed inputs must be rejected with
# structured errors, never crash the core or escape validation.
# Every (action, input) pair goes through run_cobol (the same file/serve path
# the DB suites use). Assertions, weakest to strongest:
#   1. non-empty output (no crash/hang; run_cobol fails closed on timeout),
#   2. output starts with SUCCESS| or ERROR| (protocol conformance),
#   3. the fixed malformed corpus always yields ERROR| (never bare SUCCESS),
#   4. after SQL-injection attempts the users table still exists.
# FUZZ_ACTIONS overrides the action list; FUZZ_ITERATIONS sets how many extra
# random inputs per action are generated (default 5) from the deterministic
# FUZZ_SEED (default 42). Random inputs only assert 1+2+4: random soup can be
# legitimately valid, so ERROR-only would be a false gate.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
if ! db_available 2>/dev/null; then echo "SKIP: DB unavailable"; exit 0; fi

FAIL=0
# Fixed malformed corpus: empty, huge, special chars, SQL injection attempts.
# Empirically all of these are rejected (ERROR|) on every action below; adding
# an action that accepts one of them requires updating this expectation
# deliberately (that is the gate working, not noise).
FUZZ_INPUTS=(
  ""
  "||||||"
  "'; DROP TABLE users; --||||||admin@test.com"
  "A"
  "123456789012345678901234567890"
  "NULL"
  "undefined"
  "../../../etc/passwd"
  "<script>alert(1)</script>"
)

if [ -n "${FUZZ_ACTIONS:-}" ]; then
  # shellcheck disable=SC2206
  ACTIONS=($FUZZ_ACTIONS)
else
  ACTIONS=("GLA_CREATE" "BDR_CREATE" "RPB_CREATE" "PMC_CREATE" "COL_OPEN")
fi
ITERATIONS="${FUZZ_ITERATIONS:-5}"
SEED="${FUZZ_SEED:-42}"
case "$ITERATIONS" in ''|*[!0-9]*) echo "FAIL: FUZZ_ITERATIONS must be a non-negative integer" >&2; exit 2;; esac

check_output() {
    local where="$1" out="$2" strict="$3"
    if [ -z "$out" ]; then
        echo "FAIL: $where -> empty output (crash?)"
        return 1
    fi
    case "$out" in
        SUCCESS\|*|ERROR\|*) ;;
        *)
            echo "FAIL: $where -> protocol violation: $out"
            return 1
            ;;
    esac
    if [ "$strict" = "1" ]; then
        case "$out" in
            ERROR\|*) ;;
            *)
                echo "FAIL: $where -> malformed input accepted: $out"
                return 1
                ;;
        esac
    fi
    return 0
}

count=0
for action in "${ACTIONS[@]}"; do
  for input in "${FUZZ_INPUTS[@]}"; do
    if ! out="$(run_cobol "$action|$input|||||admin@test.com" 30)"; then
        out=""
    fi
    check_output "$action with '$input'" "$out" 1 || FAIL=1
    count=$((count + 1))
  done
done

# Deterministic random soup from FUZZ_SEED (bash RANDOM reseeds on assignment).
RANDOM="$SEED"
ALPHABET=$(printf '%s' "abcXYZ019|;:'\"<>(){}[]&|*?~#\$%@!_-/\\\\. ")
for action in "${ACTIONS[@]}"; do
  for _ in $(seq 1 "$ITERATIONS"); do
    len=$((RANDOM % 64 + 1))
    input=""
    for _c in $(seq 1 "$len"); do
      input="$input${ALPHABET:$((RANDOM % ${#ALPHABET})):1}"
    done
    if ! out="$(run_cobol "$action|$input|||||admin@test.com" 30)"; then
        out=""
    fi
    check_output "$action with random soup" "$out" 0 || FAIL=1
    count=$((count + 1))
  done
done
echo "fuzzed $count (action, input) pairs"

# The injection attempts above must not have escaped validation: the users
# table must still exist. (Row counts are not asserted: suites may run
# fuzz as part of a larger concurrent run.)
if ! db_query "SELECT 1 FROM users LIMIT 1;" >/dev/null 2>&1; then
    echo "FAIL: users table unreachable after injection attempts"
    FAIL=1
else
    echo "OK: users table intact after injection attempts"
fi

if [ "$FAIL" -ne 0 ]; then exit 1; fi
echo "Fuzz testing passed: no crashes, malformed input rejected, tables intact."
