#!/usr/bin/env bash
# Debt collection (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_debt_collection

# Create a cost center.
create_out="$(run_cobol "DCL_CREATE|DCL-W7-1|DebtorA|OVERDUE|||admin@test.com")"
assert_match "DCL_CREATE ok" "$create_out" "SUCCESS\|DCL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM debt_collection WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DCL_CREATE|DCL-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DCL_GET ok" "$(run_cobol "DCL_GET|${id}|||||admin@test.com")" "SUCCESS\|DCL_GET\|${id}\|DCL-W7-1"
assert_match "DCL_LIST ok" "$(run_cobol "DCL_LIST|||50|0||admin@test.com")" "DCL-W7-1"

# Allocate.
assert_match "DCL_CALC ok" "$(run_cobol "DCL_CALC|${id}|||||admin@test.com")" "SUCCESS\|DCL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM debt_collection WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DCL_DELETE ok" "$(run_cobol "DCL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DCL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM debt_collection WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "DCL_SUMMARY ok" "$(run_cobol "DCL_SUMMARY||||||admin@test.com")" "SUCCESS\|DCL_SUMMARY"
assert_match "DCL_AUDIT ok" "$(run_cobol "DCL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DCL_AUDIT"
assert_match "DCL_VALIDATE ok" "$(run_cobol "DCL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DCL_VALID"
assert_match "non-admin refused" "$(run_cobol "DCL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0