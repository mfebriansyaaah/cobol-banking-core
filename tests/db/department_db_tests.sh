#!/usr/bin/env bash
# Department (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_department

# Create a cost center.
create_out="$(run_cobol "DPT_CREATE|DPT-W10-1|DepartmentA|OPERATIONS|||admin@test.com")"
assert_match "DPT_CREATE ok" "$create_out" "SUCCESS\|DPT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM department WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DPT_CREATE|DPT-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DPT_GET ok" "$(run_cobol "DPT_GET|${id}|||||admin@test.com")" "SUCCESS\|DPT_GET\|${id}\|DPT-W10-1"
assert_match "DPT_LIST ok" "$(run_cobol "DPT_LIST|||50|0||admin@test.com")" "DPT-W10-1"

# Allocate.
assert_match "DPT_CALC ok" "$(run_cobol "DPT_CALC|${id}|||||admin@test.com")" "SUCCESS\|DPT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM department WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DPT_DELETE ok" "$(run_cobol "DPT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DPT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM department WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "DPT_SUMMARY ok" "$(run_cobol "DPT_SUMMARY||||||admin@test.com")" "SUCCESS\|DPT_SUMMARY"
assert_match "DPT_AUDIT ok" "$(run_cobol "DPT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DPT_AUDIT"
assert_match "DPT_VALIDATE ok" "$(run_cobol "DPT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DPT_VALID"
assert_match "non-admin refused" "$(run_cobol "DPT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0