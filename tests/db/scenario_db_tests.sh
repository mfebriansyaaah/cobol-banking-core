#!/usr/bin/env bash
# Scenario (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_scenario

# Create a cost center.
create_out="$(run_cobol "SCN_CREATE|SCN-W14-1|ScenarioA|BASE|||admin@test.com")"
assert_match "SCN_CREATE ok" "$create_out" "SUCCESS\|SCN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM scenario WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SCN_CREATE|SCN-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SCN_GET ok" "$(run_cobol "SCN_GET|${id}|||||admin@test.com")" "SUCCESS\|SCN_GET\|${id}\|SCN-W14-1"
assert_match "SCN_LIST ok" "$(run_cobol "SCN_LIST|||50|0||admin@test.com")" "SCN-W14-1"

# Allocate.
assert_match "SCN_CALC ok" "$(run_cobol "SCN_CALC|${id}|||||admin@test.com")" "SUCCESS\|SCN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM scenario WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SCN_DELETE ok" "$(run_cobol "SCN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SCN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM scenario WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SCN_SUMMARY ok" "$(run_cobol "SCN_SUMMARY||||||admin@test.com")" "SUCCESS\|SCN_SUMMARY"
assert_match "SCN_AUDIT ok" "$(run_cobol "SCN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SCN_AUDIT"
assert_match "SCN_VALIDATE ok" "$(run_cobol "SCN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SCN_VALID"
assert_match "non-admin refused" "$(run_cobol "SCN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0