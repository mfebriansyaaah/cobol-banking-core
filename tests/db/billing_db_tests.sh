#!/usr/bin/env bash
# Billing (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_billing

# Create a cost center.
create_out="$(run_cobol "BIL_CREATE|BIL-W10-1|CustomerA|RECURRING|||admin@test.com")"
assert_match "BIL_CREATE ok" "$create_out" "SUCCESS\|BIL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM billing WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BIL_CREATE|BIL-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BIL_GET ok" "$(run_cobol "BIL_GET|${id}|||||admin@test.com")" "SUCCESS\|BIL_GET\|${id}\|BIL-W10-1"
assert_match "BIL_LIST ok" "$(run_cobol "BIL_LIST|||50|0||admin@test.com")" "BIL-W10-1"

# Allocate.
assert_match "BIL_CALC ok" "$(run_cobol "BIL_CALC|${id}|||||admin@test.com")" "SUCCESS\|BIL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM billing WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "BIL_DELETE ok" "$(run_cobol "BIL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|BIL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM billing WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "BIL_SUMMARY ok" "$(run_cobol "BIL_SUMMARY||||||admin@test.com")" "SUCCESS\|BIL_SUMMARY"
assert_match "BIL_AUDIT ok" "$(run_cobol "BIL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BIL_AUDIT"
assert_match "BIL_VALIDATE ok" "$(run_cobol "BIL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BIL_VALID"
assert_match "non-admin refused" "$(run_cobol "BIL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0