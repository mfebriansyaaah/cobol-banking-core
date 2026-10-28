#!/usr/bin/env bash
# Employee (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_employee

# Create a cost center.
create_out="$(run_cobol "EMP_CREATE|EMP-W10-1|EmployeeA|FULL_TIME|||admin@test.com")"
assert_match "EMP_CREATE ok" "$create_out" "SUCCESS\|EMP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM employee WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "EMP_CREATE|EMP-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "EMP_GET ok" "$(run_cobol "EMP_GET|${id}|||||admin@test.com")" "SUCCESS\|EMP_GET\|${id}\|EMP-W10-1"
assert_match "EMP_LIST ok" "$(run_cobol "EMP_LIST|||50|0||admin@test.com")" "EMP-W10-1"

# Allocate.
assert_match "EMP_CALC ok" "$(run_cobol "EMP_CALC|${id}|||||admin@test.com")" "SUCCESS\|EMP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM employee WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "EMP_DELETE ok" "$(run_cobol "EMP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|EMP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM employee WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "EMP_SUMMARY ok" "$(run_cobol "EMP_SUMMARY||||||admin@test.com")" "SUCCESS\|EMP_SUMMARY"
assert_match "EMP_AUDIT ok" "$(run_cobol "EMP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|EMP_AUDIT"
assert_match "EMP_VALIDATE ok" "$(run_cobol "EMP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|EMP_VALID"
assert_match "non-admin refused" "$(run_cobol "EMP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0