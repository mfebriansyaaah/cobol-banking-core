#!/usr/bin/env bash
# Claims management (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_claims_management

# Create a cost center.
create_out="$(run_cobol "CLM_CREATE|CLM-W7-1|ClaimA|AUTO|||admin@test.com")"
assert_match "CLM_CREATE ok" "$create_out" "SUCCESS\|CLM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM claims_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CLM_CREATE|CLM-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CLM_GET ok" "$(run_cobol "CLM_GET|${id}|||||admin@test.com")" "SUCCESS\|CLM_GET\|${id}\|CLM-W7-1"
assert_match "CLM_LIST ok" "$(run_cobol "CLM_LIST|||50|0||admin@test.com")" "CLM-W7-1"

# Allocate.
assert_match "CLM_CALC ok" "$(run_cobol "CLM_CALC|${id}|||||admin@test.com")" "SUCCESS\|CLM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM claims_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CLM_DELETE ok" "$(run_cobol "CLM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CLM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM claims_management WHERE id=${id};")" "^SETTLED$"

# Summary and audit.
assert_match "CLM_SUMMARY ok" "$(run_cobol "CLM_SUMMARY||||||admin@test.com")" "SUCCESS\|CLM_SUMMARY"
assert_match "CLM_AUDIT ok" "$(run_cobol "CLM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CLM_AUDIT"
assert_match "CLM_VALIDATE ok" "$(run_cobol "CLM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CLM_VALID"
assert_match "non-admin refused" "$(run_cobol "CLM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0