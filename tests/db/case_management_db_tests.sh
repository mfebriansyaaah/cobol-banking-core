#!/usr/bin/env bash
# case_management (Wave1) end-to-end DB tests via the COBOL binary.
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
db_reset_case_management

# Create a cost center.
create_out="$(run_cobol "CSM_CREATE|CSM-W1-1|Fraud Case|FRAUD|||admin@test.com")"
assert_match "CSM_CREATE ok" "$create_out" "SUCCESS\|CSM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM case_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CSM_CREATE|CSM-W1-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CSM_GET ok" "$(run_cobol "CSM_GET|${id}|||||admin@test.com")" "SUCCESS\|CSM_GET\|${id}\|CSM-W1-1"
assert_match "CSM_LIST ok" "$(run_cobol "CSM_LIST|||50|0||admin@test.com")" "CSM-W1-1"

# Allocate.
assert_match "CSM_CALC ok" "$(run_cobol "CSM_CALC|${id}|||||admin@test.com")" "SUCCESS\|CSM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT progress FROM case_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CSM_DELETE ok" "$(run_cobol "CSM_DELETE|${id}|RESOLVED||||admin@test.com")" "SUCCESS\|CSM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM case_management WHERE id=${id};")" "^RESOLVED$"

# Summary and audit.
assert_match "CSM_SUMMARY ok" "$(run_cobol "CSM_SUMMARY||||||admin@test.com")" "SUCCESS\|CSM_SUMMARY"
assert_match "CSM_AUDIT ok" "$(run_cobol "CSM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CSM_AUDIT"
assert_match "CSM_VALIDATE ok" "$(run_cobol "CSM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CSM_VALID"
assert_match "non-admin refused" "$(run_cobol "CSM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0