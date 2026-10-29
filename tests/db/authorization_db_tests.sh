#!/usr/bin/env bash
# Authorization (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_authorization

# Create a cost center.
create_out="$(run_cobol "AUT_CREATE|AUT-W17-1|HolderA|PAYMENT|||admin@test.com")"
assert_match "AUT_CREATE ok" "$create_out" "SUCCESS\|AUT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM authorization WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "AUT_CREATE|AUT-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "AUT_GET ok" "$(run_cobol "AUT_GET|${id}|||||admin@test.com")" "SUCCESS\|AUT_GET\|${id}\|AUT-W17-1"
assert_match "AUT_LIST ok" "$(run_cobol "AUT_LIST|||50|0||admin@test.com")" "AUT-W17-1"

# Allocate.
assert_match "AUT_CALC ok" "$(run_cobol "AUT_CALC|${id}|||||admin@test.com")" "SUCCESS\|AUT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM authorization WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "AUT_DELETE ok" "$(run_cobol "AUT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|AUT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM authorization WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "AUT_SUMMARY ok" "$(run_cobol "AUT_SUMMARY||||||admin@test.com")" "SUCCESS\|AUT_SUMMARY"
assert_match "AUT_AUDIT ok" "$(run_cobol "AUT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|AUT_AUDIT"
assert_match "AUT_VALIDATE ok" "$(run_cobol "AUT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|AUT_VALID"
assert_match "non-admin refused" "$(run_cobol "AUT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0