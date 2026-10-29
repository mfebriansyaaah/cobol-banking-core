#!/usr/bin/env bash
# Management liability (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_management_liability

# Create a cost center.
create_out="$(run_cobol "MNL_CREATE|MNL-W18-1|DirectorA|DNO|||admin@test.com")"
assert_match "MNL_CREATE ok" "$create_out" "SUCCESS\|MNL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM management_liability WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MNL_CREATE|MNL-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MNL_GET ok" "$(run_cobol "MNL_GET|${id}|||||admin@test.com")" "SUCCESS\|MNL_GET\|${id}\|MNL-W18-1"
assert_match "MNL_LIST ok" "$(run_cobol "MNL_LIST|||50|0||admin@test.com")" "MNL-W18-1"

# Allocate.
assert_match "MNL_CALC ok" "$(run_cobol "MNL_CALC|${id}|||||admin@test.com")" "SUCCESS\|MNL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM management_liability WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MNL_DELETE ok" "$(run_cobol "MNL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MNL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM management_liability WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MNL_SUMMARY ok" "$(run_cobol "MNL_SUMMARY||||||admin@test.com")" "SUCCESS\|MNL_SUMMARY"
assert_match "MNL_AUDIT ok" "$(run_cobol "MNL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MNL_AUDIT"
assert_match "MNL_VALIDATE ok" "$(run_cobol "MNL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MNL_VALID"
assert_match "non-admin refused" "$(run_cobol "MNL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0