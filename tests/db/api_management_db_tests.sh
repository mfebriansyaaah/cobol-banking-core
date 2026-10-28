#!/usr/bin/env bash
# API management (Wave5) end-to-end DB tests via the COBOL binary.
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
db_reset_api_management

# Create a cost center.
create_out="$(run_cobol "APM_CREATE|APM-W5-1|APIA|REST|||admin@test.com")"
assert_match "APM_CREATE ok" "$create_out" "SUCCESS\|APM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM api_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "APM_CREATE|APM-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "APM_GET ok" "$(run_cobol "APM_GET|${id}|||||admin@test.com")" "SUCCESS\|APM_GET\|${id}\|APM-W5-1"
assert_match "APM_LIST ok" "$(run_cobol "APM_LIST|||50|0||admin@test.com")" "APM-W5-1"

# Allocate.
assert_match "APM_CALC ok" "$(run_cobol "APM_CALC|${id}|||||admin@test.com")" "SUCCESS\|APM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT call_count FROM api_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "APM_DELETE ok" "$(run_cobol "APM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|APM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM api_management WHERE id=${id};")" "^INACTIVE$"

# Summary and audit.
assert_match "APM_SUMMARY ok" "$(run_cobol "APM_SUMMARY||||||admin@test.com")" "SUCCESS\|APM_SUMMARY"
assert_match "APM_AUDIT ok" "$(run_cobol "APM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|APM_AUDIT"
assert_match "APM_VALIDATE ok" "$(run_cobol "APM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|APM_VALID"
assert_match "non-admin refused" "$(run_cobol "APM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0