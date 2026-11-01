#!/usr/bin/env bash
# Fee velocity limits: decimal parsing and record-time enforcement.
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
db_reset_fee_velocity

create_out="$(run_cobol "VEL_PROFILE_CREATE|VEL-DB1|Daily limit|3600,100,1000.00,USD|||admin@test.com")"
assert_match "VEL_PROFILE_CREATE ok" "$create_out" "SUCCESS\|VEL_PROFILE_CREATED"

check_out="$(run_cobol "VEL_CHECK|velocity@test.com|VEL-DB1|100.00|USD||admin@test.com")"
assert_match "decimal amount is not inflated" "$check_out" "SUCCESS\|VELOCITY\|OK\|0\|0"

assert_match "first record ok" "$(run_cobol "VEL_RECORD|velocity@test.com|VEL-DB1|600.00|USD||admin@test.com")" "SUCCESS\|VELOCITY_RECORDED"
assert_match "check sees recorded usage" "$(run_cobol "VEL_CHECK|velocity@test.com|VEL-DB1|500.00|USD||admin@test.com")" "SUCCESS\|VELOCITY\|BLOCKED"

assert_match "record enforces the limit" "$(run_cobol "VEL_RECORD|velocity@test.com|VEL-DB1|600.00|USD||admin@test.com")" "ERROR\|VELOCITY_EXCEEDED"
assert_match "record within remaining limit ok" "$(run_cobol "VEL_RECORD|velocity@test.com|VEL-DB1|400.00|USD||admin@test.com")" "SUCCESS\|VELOCITY_RECORDED"
assert_match "limit reached" "$(run_cobol "VEL_CHECK|velocity@test.com|VEL-DB1|0.01|USD||admin@test.com")" "SUCCESS\|VELOCITY\|BLOCKED"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
