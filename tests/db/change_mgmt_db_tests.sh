#!/usr/bin/env bash
# Change mgmt (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_change_mgmt

# Create a cost center.
create_out="$(run_cobol "CHG2_CREATE|CHG2-W17-1|RequesterA|STANDARD|||admin@test.com")"
assert_match "CHG2_CREATE ok" "$create_out" "SUCCESS\|CHG2_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM change_mgmt WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CHG2_CREATE|CHG2-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CHG2_GET ok" "$(run_cobol "CHG2_GET|${id}|||||admin@test.com")" "SUCCESS\|CHG2_GET\|${id}\|CHG2-W17-1"
assert_match "CHG2_LIST ok" "$(run_cobol "CHG2_LIST|||50|0||admin@test.com")" "CHG2-W17-1"

# Allocate.
assert_match "CHG2_CALC ok" "$(run_cobol "CHG2_CALC|${id}|||||admin@test.com")" "SUCCESS\|CHG2_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM change_mgmt WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CHG2_DELETE ok" "$(run_cobol "CHG2_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CHG2_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM change_mgmt WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CHG2_SUMMARY ok" "$(run_cobol "CHG2_SUMMARY||||||admin@test.com")" "SUCCESS\|CHG2_SUMMARY"
assert_match "CHG2_AUDIT ok" "$(run_cobol "CHG2_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CHG2_AUDIT"
assert_match "CHG2_VALIDATE ok" "$(run_cobol "CHG2_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CHG2_VALID"
assert_match "non-admin refused" "$(run_cobol "CHG2_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0