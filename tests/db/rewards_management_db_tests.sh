#!/usr/bin/env bash
# Rewards management (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_rewards_management

# Create a cost center.
create_out="$(run_cobol "RWD_CREATE|RWD-W8-1|RewardA|CASHBACK|||admin@test.com")"
assert_match "RWD_CREATE ok" "$create_out" "SUCCESS\|RWD_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM rewards_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RWD_CREATE|RWD-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RWD_GET ok" "$(run_cobol "RWD_GET|${id}|||||admin@test.com")" "SUCCESS\|RWD_GET\|${id}\|RWD-W8-1"
assert_match "RWD_LIST ok" "$(run_cobol "RWD_LIST|||50|0||admin@test.com")" "RWD-W8-1"

# Allocate.
assert_match "RWD_CALC ok" "$(run_cobol "RWD_CALC|${id}|||||admin@test.com")" "SUCCESS\|RWD_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM rewards_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RWD_DELETE ok" "$(run_cobol "RWD_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RWD_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM rewards_management WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "RWD_SUMMARY ok" "$(run_cobol "RWD_SUMMARY||||||admin@test.com")" "SUCCESS\|RWD_SUMMARY"
assert_match "RWD_AUDIT ok" "$(run_cobol "RWD_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RWD_AUDIT"
assert_match "RWD_VALIDATE ok" "$(run_cobol "RWD_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RWD_VALID"
assert_match "non-admin refused" "$(run_cobol "RWD_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0