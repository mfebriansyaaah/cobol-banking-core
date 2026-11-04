#!/usr/bin/env bash
# payment_hold (T-020) end-to-end DB tests via the COBOL binary.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
db_reset_payment_hold

# Reserve against seeded account 1; unknown accounts are refused.
reserve_out="$(run_cobol "PHL_RESERVE|1|250.00|USD|2027-01-01||admin@test.com")"
assert_match "PHL_RESERVE ok" "$reserve_out" "SUCCESS\|PHL_RESERVED"
hold_id="$(db_query "SELECT id FROM payment_hold WHERE account_id=1 ORDER BY id DESC LIMIT 1;")"
assert_match "hold id present" "$hold_id" "^[0-9]+$"
assert_match "hold active" "$(db_query "SELECT status FROM payment_hold WHERE id=${hold_id};")" "^ACTIVE$"
assert_match "reserve unknown account" "$(run_cobol "PHL_RESERVE|999999|250.00|USD|2027-01-01||admin@test.com")" "ERROR\|NOT_FOUND"

# Read paths.
assert_match "PHL_GET ok" "$(run_cobol "PHL_GET|${hold_id}|||||admin@test.com")" "SUCCESS\|PHL_HOLD\|${hold_id}\|"
assert_match "PHL_GET missing" "$(run_cobol "PHL_GET|999999|||||admin@test.com")" "ERROR\|NOT_FOUND"
list_out="$(run_cobol "PHL_LIST|1||50|0||admin@test.com")"
assert_match "PHL_LIST ok" "$list_out" "SUCCESS\|PHL_HOLDS\|"
assert_match "list carries the hold" "$list_out" "${hold_id}:1"
assert_match "PHL_SUMMARY ok" "$(run_cobol "PHL_SUMMARY||||||admin@test.com")" "SUCCESS\|PHL_SUMMARY\|1\|1\|0\|0\|0"

# Capture; capturing twice is refused.
assert_match "PHL_CAPTURE ok" "$(run_cobol "PHL_CAPTURE|${hold_id}|||||admin@test.com")" "SUCCESS\|PHL_CAPTURED"
assert_match "hold captured" "$(db_query "SELECT status FROM payment_hold WHERE id=${hold_id};")" "^CAPTURED$"
assert_match "capture captured refused" "$(run_cobol "PHL_CAPTURE|${hold_id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"

# Release path on a second hold; releasing a captured hold is refused.
run_cobol "PHL_RESERVE|1|100.00|USD|2027-01-01||admin@test.com" >/dev/null
hold2_id="$(db_query "SELECT id FROM payment_hold WHERE account_id=1 AND amount=100.00 ORDER BY id DESC LIMIT 1;")"
assert_match "PHL_RELEASE ok" "$(run_cobol "PHL_RELEASE|${hold2_id}|||||admin@test.com")" "SUCCESS\|PHL_RELEASED"
assert_match "hold released" "$(db_query "SELECT status FROM payment_hold WHERE id=${hold2_id};")" "^RELEASED$"
assert_match "release captured refused" "$(run_cobol "PHL_RELEASE|${hold_id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"

# Expiry sweep closes a past-due hold.
run_cobol "PHL_RESERVE|1|50.00|USD|2020-01-01||admin@test.com" >/dev/null
hold3_id="$(db_query "SELECT id FROM payment_hold WHERE account_id=1 AND amount=50.00 ORDER BY id DESC LIMIT 1;")"
assert_match "PHL_EXPIRE ok" "$(run_cobol "PHL_EXPIRE||||||admin@test.com")" "SUCCESS\|PHL_EXPIRED"
assert_match "past-due hold expired" "$(db_query "SELECT status FROM payment_hold WHERE id=${hold3_id};")" "^EXPIRED$"

assert_match "missing id" "$(run_cobol "PHL_CAPTURE||||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "non-admin refused" "$(run_cobol "PHL_LIST|1||50|0||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
