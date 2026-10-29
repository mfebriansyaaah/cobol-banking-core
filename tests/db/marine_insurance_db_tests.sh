#!/usr/bin/env bash
# Marine insurance (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_marine_insurance

# Create a cost center.
create_out="$(run_cobol "MRN_CREATE|MRN-W18-1|PolicyholderA|CARGO|||admin@test.com")"
assert_match "MRN_CREATE ok" "$create_out" "SUCCESS\|MRN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM marine_insurance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MRN_CREATE|MRN-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MRN_GET ok" "$(run_cobol "MRN_GET|${id}|||||admin@test.com")" "SUCCESS\|MRN_GET\|${id}\|MRN-W18-1"
assert_match "MRN_LIST ok" "$(run_cobol "MRN_LIST|||50|0||admin@test.com")" "MRN-W18-1"

# Allocate.
assert_match "MRN_CALC ok" "$(run_cobol "MRN_CALC|${id}|||||admin@test.com")" "SUCCESS\|MRN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM marine_insurance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MRN_DELETE ok" "$(run_cobol "MRN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MRN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM marine_insurance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MRN_SUMMARY ok" "$(run_cobol "MRN_SUMMARY||||||admin@test.com")" "SUCCESS\|MRN_SUMMARY"
assert_match "MRN_AUDIT ok" "$(run_cobol "MRN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MRN_AUDIT"
assert_match "MRN_VALIDATE ok" "$(run_cobol "MRN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MRN_VALID"
assert_match "non-admin refused" "$(run_cobol "MRN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0