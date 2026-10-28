#!/usr/bin/env bash
# Whistleblowing (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_whistleblowing

# Create a cost center.
create_out="$(run_cobol "WHB_CREATE|WHB-W7-1|ReportA|ETHICS|||admin@test.com")"
assert_match "WHB_CREATE ok" "$create_out" "SUCCESS\|WHB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM whistleblowing WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "WHB_CREATE|WHB-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "WHB_GET ok" "$(run_cobol "WHB_GET|${id}|||||admin@test.com")" "SUCCESS\|WHB_GET\|${id}\|WHB-W7-1"
assert_match "WHB_LIST ok" "$(run_cobol "WHB_LIST|||50|0||admin@test.com")" "WHB-W7-1"

# Allocate.
assert_match "WHB_CALC ok" "$(run_cobol "WHB_CALC|${id}|||||admin@test.com")" "SUCCESS\|WHB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM whistleblowing WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "WHB_DELETE ok" "$(run_cobol "WHB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|WHB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM whistleblowing WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "WHB_SUMMARY ok" "$(run_cobol "WHB_SUMMARY||||||admin@test.com")" "SUCCESS\|WHB_SUMMARY"
assert_match "WHB_AUDIT ok" "$(run_cobol "WHB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|WHB_AUDIT"
assert_match "WHB_VALIDATE ok" "$(run_cobol "WHB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|WHB_VALID"
assert_match "non-admin refused" "$(run_cobol "WHB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0