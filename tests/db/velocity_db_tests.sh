#!/usr/bin/env bash
# velocity (fee module, T-020) end-to-end DB tests via the COBOL binary.
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
db_reset_velocity
# Fase 2: transfers everywhere consult enabled velocity profiles, so this
# suite owns its profiles and removes them afterwards; a leftover
# max_count=1 profile would veto other suites' transfers.
db_exec "DELETE FROM velocity_counter WHERE profile_code LIKE 'VEL-T%';"
db_exec "DELETE FROM velocity_profile WHERE profile_code LIKE 'VEL-T%';"

# Hourly profile: 3600s window, 10 events, 5000.00 USD cap.
create_out="$(run_cobol "VEL_PROFILE_CREATE|VEL-T1|Hourly cap|3600,10,5000.00,USD|||admin@test.com")"
assert_match "VEL_PROFILE_CREATE ok" "$create_out" "SUCCESS\|VEL_PROFILE_CREATED"
assert_match "duplicate profile refused" "$(run_cobol "VEL_PROFILE_CREATE|VEL-T1|Hourly cap|3600,10,5000.00,USD|||admin@test.com")" "ERROR\|DB_ERROR"
list_out="$(run_cobol "VEL_PROFILE_LIST|50|0||||admin@test.com")"
assert_match "VEL_PROFILE_LIST ok" "$list_out" "SUCCESS\|VEL_PROFILES\|1\|"
assert_match "list carries the profile" "$list_out" "VEL-T1"

# Fresh check passes with zero usage; recording consumes one event.
assert_match "VEL_CHECK ok" "$(run_cobol "VEL_CHECK|user@test.com|VEL-T1|100.00|USD||admin@test.com")" "SUCCESS\|VELOCITY\|OK\|0\|"
assert_match "VEL_RECORD ok" "$(run_cobol "VEL_RECORD|user@test.com|VEL-T1|100.00|USD||admin@test.com")" "SUCCESS\|VELOCITY_RECORDED"
assert_match "counter row written" "$(db_query "SELECT used_count FROM velocity_counter WHERE account_email='user@test.com' AND profile_code='VEL-T1';")" "^1$"
assert_match "VEL_USAGE ok" "$(run_cobol "VEL_USAGE|user@test.com|VEL-T1||||admin@test.com")" "SUCCESS\|VEL_USAGE\|1\|"
assert_match "check after record" "$(run_cobol "VEL_CHECK|user@test.com|VEL-T1|100.00|USD||admin@test.com")" "SUCCESS\|VELOCITY\|OK\|1\|"

# Single-event profile: the second check is blocked.
run_cobol "VEL_PROFILE_CREATE|VEL-T2|Single|3600,1,5000.00,USD|||admin@test.com" >/dev/null
run_cobol "VEL_RECORD|user@test.com|VEL-T2|10.00|USD||admin@test.com" >/dev/null
assert_match "over-limit check blocked" "$(run_cobol "VEL_CHECK|user@test.com|VEL-T2|10.00|USD||admin@test.com")" "SUCCESS\|VELOCITY\|BLOCKED\|"

# Wrong currency and unknown profile are refused.
assert_match "currency mismatch" "$(run_cobol "VEL_RECORD|user@test.com|VEL-T1|10.00|EUR||admin@test.com")" "ERROR\|CURRENCY_MISMATCH"
assert_match "record unknown profile" "$(run_cobol "VEL_RECORD|user@test.com|NOPE|10.00|USD||admin@test.com")" "ERROR\|NOT_FOUND"
assert_match "check unknown profile" "$(run_cobol "VEL_CHECK|user@test.com|NOPE|10.00|USD||admin@test.com")" "ERROR\|NOT_FOUND"

assert_match "missing input" "$(run_cobol "VEL_CHECK||||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "non-admin refused" "$(run_cobol "VEL_PROFILE_LIST|50|0||||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM velocity_counter WHERE profile_code LIKE 'VEL-T%';"
db_exec "DELETE FROM velocity_profile WHERE profile_code LIKE 'VEL-T%';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
