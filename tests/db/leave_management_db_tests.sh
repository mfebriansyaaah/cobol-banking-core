#!/usr/bin/env bash
# Leave management (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_leave_management

# Create a cost center.
create_out="$(run_cobol "LEA_CREATE|LEA-W10-1|RequestA|ANNUAL|||admin@test.com")"
assert_match "LEA_CREATE ok" "$create_out" "SUCCESS\|LEA_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM leave_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "LEA_CREATE|LEA-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "LEA_GET ok" "$(run_cobol "LEA_GET|${id}|||||admin@test.com")" "SUCCESS\|LEA_GET\|${id}\|LEA-W10-1"
assert_match "LEA_LIST ok" "$(run_cobol "LEA_LIST|||50|0||admin@test.com")" "LEA-W10-1"

# Allocate.
assert_match "LEA_CALC ok" "$(run_cobol "LEA_CALC|${id}|||||admin@test.com")" "SUCCESS\|LEA_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM leave_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "LEA_DELETE ok" "$(run_cobol "LEA_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|LEA_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM leave_management WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "LEA_SUMMARY ok" "$(run_cobol "LEA_SUMMARY||||||admin@test.com")" "SUCCESS\|LEA_SUMMARY"
assert_match "LEA_AUDIT ok" "$(run_cobol "LEA_AUDIT|50|0||||admin@test.com")" "SUCCESS\|LEA_AUDIT"
assert_match "LEA_VALIDATE ok" "$(run_cobol "LEA_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|LEA_VALID"
assert_match "non-admin refused" "$(run_cobol "LEA_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0