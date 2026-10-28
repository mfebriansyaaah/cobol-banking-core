#!/usr/bin/env bash
# Vendor management (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_vendor_management

# Create a cost center.
create_out="$(run_cobol "VDM_CREATE|VDM-W7-1|VendorA|IT|||admin@test.com")"
assert_match "VDM_CREATE ok" "$create_out" "SUCCESS\|VDM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM vendor_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "VDM_CREATE|VDM-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "VDM_GET ok" "$(run_cobol "VDM_GET|${id}|||||admin@test.com")" "SUCCESS\|VDM_GET\|${id}\|VDM-W7-1"
assert_match "VDM_LIST ok" "$(run_cobol "VDM_LIST|||50|0||admin@test.com")" "VDM-W7-1"

# Allocate.
assert_match "VDM_CALC ok" "$(run_cobol "VDM_CALC|${id}|||||admin@test.com")" "SUCCESS\|VDM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM vendor_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "VDM_DELETE ok" "$(run_cobol "VDM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|VDM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM vendor_management WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "VDM_SUMMARY ok" "$(run_cobol "VDM_SUMMARY||||||admin@test.com")" "SUCCESS\|VDM_SUMMARY"
assert_match "VDM_AUDIT ok" "$(run_cobol "VDM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|VDM_AUDIT"
assert_match "VDM_VALIDATE ok" "$(run_cobol "VDM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|VDM_VALID"
assert_match "non-admin refused" "$(run_cobol "VDM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0