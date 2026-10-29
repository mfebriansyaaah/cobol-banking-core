#!/usr/bin/env bash
# Health insurance (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_health_insurance

# Create a cost center.
create_out="$(run_cobol "HLT_CREATE|HLT-W18-1|PolicyholderA|MEDICAL|||admin@test.com")"
assert_match "HLT_CREATE ok" "$create_out" "SUCCESS\|HLT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM health_insurance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "HLT_CREATE|HLT-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "HLT_GET ok" "$(run_cobol "HLT_GET|${id}|||||admin@test.com")" "SUCCESS\|HLT_GET\|${id}\|HLT-W18-1"
assert_match "HLT_LIST ok" "$(run_cobol "HLT_LIST|||50|0||admin@test.com")" "HLT-W18-1"

# Allocate.
assert_match "HLT_CALC ok" "$(run_cobol "HLT_CALC|${id}|||||admin@test.com")" "SUCCESS\|HLT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM health_insurance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "HLT_DELETE ok" "$(run_cobol "HLT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|HLT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM health_insurance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "HLT_SUMMARY ok" "$(run_cobol "HLT_SUMMARY||||||admin@test.com")" "SUCCESS\|HLT_SUMMARY"
assert_match "HLT_AUDIT ok" "$(run_cobol "HLT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|HLT_AUDIT"
assert_match "HLT_VALIDATE ok" "$(run_cobol "HLT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|HLT_VALID"
assert_match "non-admin refused" "$(run_cobol "HLT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0