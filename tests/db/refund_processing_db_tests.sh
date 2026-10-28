#!/usr/bin/env bash
# Refund processing (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_refund_processing

# Create a cost center.
create_out="$(run_cobol "RFP_CREATE|RFP-W6-1|CustomerA|CANCEL|||admin@test.com")"
assert_match "RFP_CREATE ok" "$create_out" "SUCCESS\|RFP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM refund_processing WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RFP_CREATE|RFP-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RFP_GET ok" "$(run_cobol "RFP_GET|${id}|||||admin@test.com")" "SUCCESS\|RFP_GET\|${id}\|RFP-W6-1"
assert_match "RFP_LIST ok" "$(run_cobol "RFP_LIST|||50|0||admin@test.com")" "RFP-W6-1"

# Allocate.
assert_match "RFP_CALC ok" "$(run_cobol "RFP_CALC|${id}|||||admin@test.com")" "SUCCESS\|RFP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM refund_processing WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RFP_DELETE ok" "$(run_cobol "RFP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RFP_DELETE"
assert_match "completed persisted" "$(db_query "SELECT status FROM refund_processing WHERE id=${id};")" "^COMPLETED$"

# Summary and audit.
assert_match "RFP_SUMMARY ok" "$(run_cobol "RFP_SUMMARY||||||admin@test.com")" "SUCCESS\|RFP_SUMMARY"
assert_match "RFP_AUDIT ok" "$(run_cobol "RFP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RFP_AUDIT"
assert_match "RFP_VALIDATE ok" "$(run_cobol "RFP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RFP_VALID"
assert_match "non-admin refused" "$(run_cobol "RFP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0