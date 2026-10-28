#!/usr/bin/env bash
# Change approval (D20) end-to-end DB tests via the COBOL binary.
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
db_reset_change_approval

# Create a cost center.
create_out="$(run_cobol "CHA_CREATE|CHA-D20-1|ChangeA|CHG|||admin@test.com")"
assert_match "CHA_CREATE ok" "$create_out" "SUCCESS\|CHA_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM change_approval WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CHA_CREATE|CHA-D20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CHA_GET ok" "$(run_cobol "CHA_GET|${id}|||||admin@test.com")" "SUCCESS\|CHA_GET\|${id}\|CHA-D20-1"
assert_match "CHA_LIST ok" "$(run_cobol "CHA_LIST|||50|0||admin@test.com")" "CHA-D20-1"

# Allocate.
assert_match "CHA_CALC ok" "$(run_cobol "CHA_CALC|${id}|||||admin@test.com")" "SUCCESS\|CHA_CALC\|1"
assert_match "posted persisted" "$(db_query "SELECT approved_amount FROM change_approval WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CHA_DELETE ok" "$(run_cobol "CHA_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CHA_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM change_approval WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CHA_SUMMARY ok" "$(run_cobol "CHA_SUMMARY||||||admin@test.com")" "SUCCESS\|CHA_SUMMARY"
assert_match "CHA_AUDIT ok" "$(run_cobol "CHA_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CHA_AUDIT"
assert_match "CHA_VALIDATE ok" "$(run_cobol "CHA_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CHA_VALID"
assert_match "non-admin refused" "$(run_cobol "CHA_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0