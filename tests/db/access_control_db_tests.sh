#!/usr/bin/env bash
# Access control (Wave5) end-to-end DB tests via the COBOL binary.
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
db_reset_access_control

# Create a cost center.
create_out="$(run_cobol "AXC_CREATE|AXC-W5-1|ResourceA|READ|||admin@test.com")"
assert_match "AXC_CREATE ok" "$create_out" "SUCCESS\|AXC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM access_control WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "AXC_CREATE|AXC-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "AXC_GET ok" "$(run_cobol "AXC_GET|${id}|||||admin@test.com")" "SUCCESS\|AXC_GET\|${id}\|AXC-W5-1"
assert_match "AXC_LIST ok" "$(run_cobol "AXC_LIST|||50|0||admin@test.com")" "AXC-W5-1"

# Allocate.
assert_match "AXC_CALC ok" "$(run_cobol "AXC_CALC|${id}|||||admin@test.com")" "SUCCESS\|AXC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT access_count FROM access_control WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "AXC_DELETE ok" "$(run_cobol "AXC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|AXC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM access_control WHERE id=${id};")" "^REVOKED$"

# Summary and audit.
assert_match "AXC_SUMMARY ok" "$(run_cobol "AXC_SUMMARY||||||admin@test.com")" "SUCCESS\|AXC_SUMMARY"
assert_match "AXC_AUDIT ok" "$(run_cobol "AXC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|AXC_AUDIT"
assert_match "AXC_VALIDATE ok" "$(run_cobol "AXC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|AXC_VALID"
assert_match "non-admin refused" "$(run_cobol "AXC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0