#!/usr/bin/env bash
# Compensation (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_compensation

# Create a cost center.
create_out="$(run_cobol "COM_CREATE|COM-W10-1|EmployeeA|SALARY|||admin@test.com")"
assert_match "COM_CREATE ok" "$create_out" "SUCCESS\|COM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM compensation WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "COM_CREATE|COM-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "COM_GET ok" "$(run_cobol "COM_GET|${id}|||||admin@test.com")" "SUCCESS\|COM_GET\|${id}\|COM-W10-1"
assert_match "COM_LIST ok" "$(run_cobol "COM_LIST|||50|0||admin@test.com")" "COM-W10-1"

# Allocate.
assert_match "COM_CALC ok" "$(run_cobol "COM_CALC|${id}|||||admin@test.com")" "SUCCESS\|COM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM compensation WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "COM_DELETE ok" "$(run_cobol "COM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|COM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM compensation WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "COM_SUMMARY ok" "$(run_cobol "COM_SUMMARY||||||admin@test.com")" "SUCCESS\|COM_SUMMARY"
assert_match "COM_AUDIT ok" "$(run_cobol "COM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|COM_AUDIT"
assert_match "COM_VALIDATE ok" "$(run_cobol "COM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|COM_VALID"
assert_match "non-admin refused" "$(run_cobol "COM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0