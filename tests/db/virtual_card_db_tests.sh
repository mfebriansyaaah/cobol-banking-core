#!/usr/bin/env bash
# Virtual card (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_virtual_card

# Create a cost center.
create_out="$(run_cobol "VRC_CREATE|VRC-W8-1|CardholderA|SINGLE_USE|||admin@test.com")"
assert_match "VRC_CREATE ok" "$create_out" "SUCCESS\|VRC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM virtual_card WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "VRC_CREATE|VRC-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "VRC_GET ok" "$(run_cobol "VRC_GET|${id}|||||admin@test.com")" "SUCCESS\|VRC_GET\|${id}\|VRC-W8-1"
assert_match "VRC_LIST ok" "$(run_cobol "VRC_LIST|||50|0||admin@test.com")" "VRC-W8-1"

# Allocate.
assert_match "VRC_CALC ok" "$(run_cobol "VRC_CALC|${id}|||||admin@test.com")" "SUCCESS\|VRC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM virtual_card WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "VRC_DELETE ok" "$(run_cobol "VRC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|VRC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM virtual_card WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "VRC_SUMMARY ok" "$(run_cobol "VRC_SUMMARY||||||admin@test.com")" "SUCCESS\|VRC_SUMMARY"
assert_match "VRC_AUDIT ok" "$(run_cobol "VRC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|VRC_AUDIT"
assert_match "VRC_VALIDATE ok" "$(run_cobol "VRC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|VRC_VALID"
assert_match "non-admin refused" "$(run_cobol "VRC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0