#!/usr/bin/env bash
# Device management (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_device_management

# Create a cost center.
create_out="$(run_cobol "DVM_CREATE|DVM-W8-1|DeviceA|MOBILE|||admin@test.com")"
assert_match "DVM_CREATE ok" "$create_out" "SUCCESS\|DVM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM device_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DVM_CREATE|DVM-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DVM_GET ok" "$(run_cobol "DVM_GET|${id}|||||admin@test.com")" "SUCCESS\|DVM_GET\|${id}\|DVM-W8-1"
assert_match "DVM_LIST ok" "$(run_cobol "DVM_LIST|||50|0||admin@test.com")" "DVM-W8-1"

# Allocate.
assert_match "DVM_CALC ok" "$(run_cobol "DVM_CALC|${id}|||||admin@test.com")" "SUCCESS\|DVM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM device_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DVM_DELETE ok" "$(run_cobol "DVM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DVM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM device_management WHERE id=${id};")" "^DEREGISTERED$"

# Summary and audit.
assert_match "DVM_SUMMARY ok" "$(run_cobol "DVM_SUMMARY||||||admin@test.com")" "SUCCESS\|DVM_SUMMARY"
assert_match "DVM_AUDIT ok" "$(run_cobol "DVM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DVM_AUDIT"
assert_match "DVM_VALIDATE ok" "$(run_cobol "DVM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DVM_VALID"
assert_match "non-admin refused" "$(run_cobol "DVM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0