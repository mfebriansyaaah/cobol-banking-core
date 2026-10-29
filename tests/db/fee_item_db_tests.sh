#!/usr/bin/env bash
# Fee item (Wave15) end-to-end DB tests via the COBOL binary.
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
db_reset_fee_item

# Create a cost center.
create_out="$(run_cobol "FEES_CREATE|FEES-W15-1|AccountA|SERVICE|||admin@test.com")"
assert_match "FEES_CREATE ok" "$create_out" "SUCCESS\|FEES_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM fee_item WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FEES_CREATE|FEES-W15-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FEES_GET ok" "$(run_cobol "FEES_GET|${id}|||||admin@test.com")" "SUCCESS\|FEES_GET\|${id}\|FEES-W15-1"
assert_match "FEES_LIST ok" "$(run_cobol "FEES_LIST|||50|0||admin@test.com")" "FEES-W15-1"

# Allocate.
assert_match "FEES_CALC ok" "$(run_cobol "FEES_CALC|${id}|||||admin@test.com")" "SUCCESS\|FEES_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM fee_item WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FEES_DELETE ok" "$(run_cobol "FEES_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FEES_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM fee_item WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "FEES_SUMMARY ok" "$(run_cobol "FEES_SUMMARY||||||admin@test.com")" "SUCCESS\|FEES_SUMMARY"
assert_match "FEES_AUDIT ok" "$(run_cobol "FEES_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FEES_AUDIT"
assert_match "FEES_VALIDATE ok" "$(run_cobol "FEES_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FEES_VALID"
assert_match "non-admin refused" "$(run_cobol "FEES_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0