#!/usr/bin/env bash
# Deployment (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_deployment

# Create a cost center.
create_out="$(run_cobol "DEP2_CREATE|DEP2-W17-1|ServiceA|PRODUCTION|||admin@test.com")"
assert_match "DEP2_CREATE ok" "$create_out" "SUCCESS\|DEP2_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM deployment WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DEP2_CREATE|DEP2-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DEP2_GET ok" "$(run_cobol "DEP2_GET|${id}|||||admin@test.com")" "SUCCESS\|DEP2_GET\|${id}\|DEP2-W17-1"
assert_match "DEP2_LIST ok" "$(run_cobol "DEP2_LIST|||50|0||admin@test.com")" "DEP2-W17-1"

# Allocate.
assert_match "DEP2_CALC ok" "$(run_cobol "DEP2_CALC|${id}|||||admin@test.com")" "SUCCESS\|DEP2_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM deployment WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DEP2_DELETE ok" "$(run_cobol "DEP2_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DEP2_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM deployment WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "DEP2_SUMMARY ok" "$(run_cobol "DEP2_SUMMARY||||||admin@test.com")" "SUCCESS\|DEP2_SUMMARY"
assert_match "DEP2_AUDIT ok" "$(run_cobol "DEP2_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DEP2_AUDIT"
assert_match "DEP2_VALIDATE ok" "$(run_cobol "DEP2_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DEP2_VALID"
assert_match "non-admin refused" "$(run_cobol "DEP2_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0