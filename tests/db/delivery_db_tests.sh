#!/usr/bin/env bash
# Delivery (Wave19) end-to-end DB tests via the COBOL binary.
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
db_reset_delivery

# Create a cost center.
create_out="$(run_cobol "DLV_CREATE|DLV-W19-1|DeliveryA|LAST_MILE|||admin@test.com")"
assert_match "DLV_CREATE ok" "$create_out" "SUCCESS\|DLV_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM delivery WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DLV_CREATE|DLV-W19-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DLV_GET ok" "$(run_cobol "DLV_GET|${id}|||||admin@test.com")" "SUCCESS\|DLV_GET\|${id}\|DLV-W19-1"
assert_match "DLV_LIST ok" "$(run_cobol "DLV_LIST|||50|0||admin@test.com")" "DLV-W19-1"

# Allocate.
assert_match "DLV_CALC ok" "$(run_cobol "DLV_CALC|${id}|||||admin@test.com")" "SUCCESS\|DLV_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM delivery WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DLV_DELETE ok" "$(run_cobol "DLV_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DLV_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM delivery WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "DLV_SUMMARY ok" "$(run_cobol "DLV_SUMMARY||||||admin@test.com")" "SUCCESS\|DLV_SUMMARY"
assert_match "DLV_AUDIT ok" "$(run_cobol "DLV_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DLV_AUDIT"
assert_match "DLV_VALIDATE ok" "$(run_cobol "DLV_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DLV_VALID"
assert_match "non-admin refused" "$(run_cobol "DLV_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0