#!/usr/bin/env bash
# Commission item (Wave15) end-to-end DB tests via the COBOL binary.
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
db_reset_commission_item

# Create a cost center.
create_out="$(run_cobol "COMM_CREATE|COMM-W15-1|AccountA|SALES|||admin@test.com")"
assert_match "COMM_CREATE ok" "$create_out" "SUCCESS\|COMM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM commission_item WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "COMM_CREATE|COMM-W15-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "COMM_GET ok" "$(run_cobol "COMM_GET|${id}|||||admin@test.com")" "SUCCESS\|COMM_GET\|${id}\|COMM-W15-1"
assert_match "COMM_LIST ok" "$(run_cobol "COMM_LIST|||50|0||admin@test.com")" "COMM-W15-1"

# Allocate.
assert_match "COMM_CALC ok" "$(run_cobol "COMM_CALC|${id}|||||admin@test.com")" "SUCCESS\|COMM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM commission_item WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "COMM_DELETE ok" "$(run_cobol "COMM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|COMM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM commission_item WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "COMM_SUMMARY ok" "$(run_cobol "COMM_SUMMARY||||||admin@test.com")" "SUCCESS\|COMM_SUMMARY"
assert_match "COMM_AUDIT ok" "$(run_cobol "COMM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|COMM_AUDIT"
assert_match "COMM_VALIDATE ok" "$(run_cobol "COMM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|COMM_VALID"
assert_match "non-admin refused" "$(run_cobol "COMM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0