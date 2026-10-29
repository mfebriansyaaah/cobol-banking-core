#!/usr/bin/env bash
# Branch banking (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_branch_banking

# Create a cost center.
create_out="$(run_cobol "BRK_CREATE|BRK-W20-1|BranchA|FULL_SERVICE|||admin@test.com")"
assert_match "BRK_CREATE ok" "$create_out" "SUCCESS\|BRK_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM branch_banking WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BRK_CREATE|BRK-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BRK_GET ok" "$(run_cobol "BRK_GET|${id}|||||admin@test.com")" "SUCCESS\|BRK_GET\|${id}\|BRK-W20-1"
assert_match "BRK_LIST ok" "$(run_cobol "BRK_LIST|||50|0||admin@test.com")" "BRK-W20-1"

# Allocate.
assert_match "BRK_CALC ok" "$(run_cobol "BRK_CALC|${id}|||||admin@test.com")" "SUCCESS\|BRK_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM branch_banking WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "BRK_DELETE ok" "$(run_cobol "BRK_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|BRK_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM branch_banking WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "BRK_SUMMARY ok" "$(run_cobol "BRK_SUMMARY||||||admin@test.com")" "SUCCESS\|BRK_SUMMARY"
assert_match "BRK_AUDIT ok" "$(run_cobol "BRK_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BRK_AUDIT"
assert_match "BRK_VALIDATE ok" "$(run_cobol "BRK_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BRK_VALID"
assert_match "non-admin refused" "$(run_cobol "BRK_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0