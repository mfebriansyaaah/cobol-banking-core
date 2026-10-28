#!/usr/bin/env bash
# Crisis management (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_crisis_management

# Create a cost center.
create_out="$(run_cobol "CRM_CREATE|CRM-W7-1|CrisisA|SYSTEM|||admin@test.com")"
assert_match "CRM_CREATE ok" "$create_out" "SUCCESS\|CRM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM crisis_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CRM_CREATE|CRM-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CRM_GET ok" "$(run_cobol "CRM_GET|${id}|||||admin@test.com")" "SUCCESS\|CRM_GET\|${id}\|CRM-W7-1"
assert_match "CRM_LIST ok" "$(run_cobol "CRM_LIST|||50|0||admin@test.com")" "CRM-W7-1"

# Allocate.
assert_match "CRM_CALC ok" "$(run_cobol "CRM_CALC|${id}|||||admin@test.com")" "SUCCESS\|CRM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM crisis_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CRM_DELETE ok" "$(run_cobol "CRM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CRM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM crisis_management WHERE id=${id};")" "^RESOLVED$"

# Summary and audit.
assert_match "CRM_SUMMARY ok" "$(run_cobol "CRM_SUMMARY||||||admin@test.com")" "SUCCESS\|CRM_SUMMARY"
assert_match "CRM_AUDIT ok" "$(run_cobol "CRM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CRM_AUDIT"
assert_match "CRM_VALIDATE ok" "$(run_cobol "CRM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CRM_VALID"
assert_match "non-admin refused" "$(run_cobol "CRM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0