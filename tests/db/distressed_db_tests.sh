#!/usr/bin/env bash
# Distressed (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_distressed

# Create a cost center.
create_out="$(run_cobol "DIS_CREATE|DIS-W12-1|AssetA|RESTRUCTURING|||admin@test.com")"
assert_match "DIS_CREATE ok" "$create_out" "SUCCESS\|DIS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM distressed WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DIS_CREATE|DIS-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DIS_GET ok" "$(run_cobol "DIS_GET|${id}|||||admin@test.com")" "SUCCESS\|DIS_GET\|${id}\|DIS-W12-1"
assert_match "DIS_LIST ok" "$(run_cobol "DIS_LIST|||50|0||admin@test.com")" "DIS-W12-1"

# Allocate.
assert_match "DIS_CALC ok" "$(run_cobol "DIS_CALC|${id}|||||admin@test.com")" "SUCCESS\|DIS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM distressed WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DIS_DELETE ok" "$(run_cobol "DIS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DIS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM distressed WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "DIS_SUMMARY ok" "$(run_cobol "DIS_SUMMARY||||||admin@test.com")" "SUCCESS\|DIS_SUMMARY"
assert_match "DIS_AUDIT ok" "$(run_cobol "DIS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DIS_AUDIT"
assert_match "DIS_VALIDATE ok" "$(run_cobol "DIS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DIS_VALID"
assert_match "non-admin refused" "$(run_cobol "DIS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0