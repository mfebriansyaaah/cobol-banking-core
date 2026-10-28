#!/usr/bin/env bash
# Balance sheet (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_balance_sheet

# Create a cost center.
create_out="$(run_cobol "BS_CREATE|BS-W13-1|EntityA|CONSOLIDATED|||admin@test.com")"
assert_match "BS_CREATE ok" "$create_out" "SUCCESS\|BS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM balance_sheet WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BS_CREATE|BS-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BS_GET ok" "$(run_cobol "BS_GET|${id}|||||admin@test.com")" "SUCCESS\|BS_GET\|${id}\|BS-W13-1"
assert_match "BS_LIST ok" "$(run_cobol "BS_LIST|||50|0||admin@test.com")" "BS-W13-1"

# Allocate.
assert_match "BS_CALC ok" "$(run_cobol "BS_CALC|${id}|||||admin@test.com")" "SUCCESS\|BS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM balance_sheet WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "BS_DELETE ok" "$(run_cobol "BS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|BS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM balance_sheet WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "BS_SUMMARY ok" "$(run_cobol "BS_SUMMARY||||||admin@test.com")" "SUCCESS\|BS_SUMMARY"
assert_match "BS_AUDIT ok" "$(run_cobol "BS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BS_AUDIT"
assert_match "BS_VALIDATE ok" "$(run_cobol "BS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BS_VALID"
assert_match "non-admin refused" "$(run_cobol "BS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0