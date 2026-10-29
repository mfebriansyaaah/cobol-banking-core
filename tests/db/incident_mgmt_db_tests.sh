#!/usr/bin/env bash
# Incident mgmt (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_incident_mgmt

# Create a cost center.
create_out="$(run_cobol "INCD_CREATE|INCD-W17-1|ReporterA|OUTAGE|||admin@test.com")"
assert_match "INCD_CREATE ok" "$create_out" "SUCCESS\|INCD_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM incident_mgmt WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "INCD_CREATE|INCD-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "INCD_GET ok" "$(run_cobol "INCD_GET|${id}|||||admin@test.com")" "SUCCESS\|INCD_GET\|${id}\|INCD-W17-1"
assert_match "INCD_LIST ok" "$(run_cobol "INCD_LIST|||50|0||admin@test.com")" "INCD-W17-1"

# Allocate.
assert_match "INCD_CALC ok" "$(run_cobol "INCD_CALC|${id}|||||admin@test.com")" "SUCCESS\|INCD_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM incident_mgmt WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "INCD_DELETE ok" "$(run_cobol "INCD_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|INCD_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM incident_mgmt WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "INCD_SUMMARY ok" "$(run_cobol "INCD_SUMMARY||||||admin@test.com")" "SUCCESS\|INCD_SUMMARY"
assert_match "INCD_AUDIT ok" "$(run_cobol "INCD_AUDIT|50|0||||admin@test.com")" "SUCCESS\|INCD_AUDIT"
assert_match "INCD_VALIDATE ok" "$(run_cobol "INCD_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|INCD_VALID"
assert_match "non-admin refused" "$(run_cobol "INCD_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0