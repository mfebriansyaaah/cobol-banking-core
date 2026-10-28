#!/usr/bin/env bash
# Incident report (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_incident_report

# Create a cost center.
create_out="$(run_cobol "INR_CREATE|INR-W7-1|IncidentA|SECURITY|||admin@test.com")"
assert_match "INR_CREATE ok" "$create_out" "SUCCESS\|INR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM incident_report WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "INR_CREATE|INR-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "INR_GET ok" "$(run_cobol "INR_GET|${id}|||||admin@test.com")" "SUCCESS\|INR_GET\|${id}\|INR-W7-1"
assert_match "INR_LIST ok" "$(run_cobol "INR_LIST|||50|0||admin@test.com")" "INR-W7-1"

# Allocate.
assert_match "INR_CALC ok" "$(run_cobol "INR_CALC|${id}|||||admin@test.com")" "SUCCESS\|INR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM incident_report WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "INR_DELETE ok" "$(run_cobol "INR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|INR_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM incident_report WHERE id=${id};")" "^RESOLVED$"

# Summary and audit.
assert_match "INR_SUMMARY ok" "$(run_cobol "INR_SUMMARY||||||admin@test.com")" "SUCCESS\|INR_SUMMARY"
assert_match "INR_AUDIT ok" "$(run_cobol "INR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|INR_AUDIT"
assert_match "INR_VALIDATE ok" "$(run_cobol "INR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|INR_VALID"
assert_match "non-admin refused" "$(run_cobol "INR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0