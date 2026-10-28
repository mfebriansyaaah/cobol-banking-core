#!/usr/bin/env bash
# Fill (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_fill

# Create a cost center.
create_out="$(run_cobol "FIL_CREATE|FIL-W14-1|FillA|PARTIAL|||admin@test.com")"
assert_match "FIL_CREATE ok" "$create_out" "SUCCESS\|FIL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM fill WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FIL_CREATE|FIL-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FIL_GET ok" "$(run_cobol "FIL_GET|${id}|||||admin@test.com")" "SUCCESS\|FIL_GET\|${id}\|FIL-W14-1"
assert_match "FIL_LIST ok" "$(run_cobol "FIL_LIST|||50|0||admin@test.com")" "FIL-W14-1"

# Allocate.
assert_match "FIL_CALC ok" "$(run_cobol "FIL_CALC|${id}|||||admin@test.com")" "SUCCESS\|FIL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM fill WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FIL_DELETE ok" "$(run_cobol "FIL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FIL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM fill WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "FIL_SUMMARY ok" "$(run_cobol "FIL_SUMMARY||||||admin@test.com")" "SUCCESS\|FIL_SUMMARY"
assert_match "FIL_AUDIT ok" "$(run_cobol "FIL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FIL_AUDIT"
assert_match "FIL_VALIDATE ok" "$(run_cobol "FIL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FIL_VALID"
assert_match "non-admin refused" "$(run_cobol "FIL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0