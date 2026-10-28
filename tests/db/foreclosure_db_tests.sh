#!/usr/bin/env bash
# Foreclosure (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_foreclosure

# Create a cost center.
create_out="$(run_cobol "FCL_CREATE|FCL-W7-1|PropertyA|PROPERTY|||admin@test.com")"
assert_match "FCL_CREATE ok" "$create_out" "SUCCESS\|FCL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM foreclosure WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FCL_CREATE|FCL-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FCL_GET ok" "$(run_cobol "FCL_GET|${id}|||||admin@test.com")" "SUCCESS\|FCL_GET\|${id}\|FCL-W7-1"
assert_match "FCL_LIST ok" "$(run_cobol "FCL_LIST|||50|0||admin@test.com")" "FCL-W7-1"

# Allocate.
assert_match "FCL_CALC ok" "$(run_cobol "FCL_CALC|${id}|||||admin@test.com")" "SUCCESS\|FCL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM foreclosure WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FCL_DELETE ok" "$(run_cobol "FCL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FCL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM foreclosure WHERE id=${id};")" "^FORECLOSED$"

# Summary and audit.
assert_match "FCL_SUMMARY ok" "$(run_cobol "FCL_SUMMARY||||||admin@test.com")" "SUCCESS\|FCL_SUMMARY"
assert_match "FCL_AUDIT ok" "$(run_cobol "FCL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FCL_AUDIT"
assert_match "FCL_VALIDATE ok" "$(run_cobol "FCL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FCL_VALID"
assert_match "non-admin refused" "$(run_cobol "FCL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0