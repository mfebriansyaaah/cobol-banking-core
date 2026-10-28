#!/usr/bin/env bash
# Incident postmortem (D19) end-to-end DB tests via the COBOL binary.
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
db_reset_incident_postmortem

# Create a cost center.
create_out="$(run_cobol "IPM_CREATE|IPM-D19-1|IncidentA|OPS|||admin@test.com")"
assert_match "IPM_CREATE ok" "$create_out" "SUCCESS\|IPM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM incident_postmortem WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "IPM_CREATE|IPM-D19-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "IPM_GET ok" "$(run_cobol "IPM_GET|${id}|||||admin@test.com")" "SUCCESS\|IPM_GET\|${id}\|IPM-D19-1"
assert_match "IPM_LIST ok" "$(run_cobol "IPM_LIST|||50|0||admin@test.com")" "IPM-D19-1"

# Allocate.
assert_match "IPM_CALC ok" "$(run_cobol "IPM_CALC|${id}|||||admin@test.com")" "SUCCESS\|IPM_CALC\|1"
assert_match "posted persisted" "$(db_query "SELECT reviewed_amount FROM incident_postmortem WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "IPM_DELETE ok" "$(run_cobol "IPM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|IPM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM incident_postmortem WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "IPM_SUMMARY ok" "$(run_cobol "IPM_SUMMARY||||||admin@test.com")" "SUCCESS\|IPM_SUMMARY"
assert_match "IPM_AUDIT ok" "$(run_cobol "IPM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|IPM_AUDIT"
assert_match "IPM_VALIDATE ok" "$(run_cobol "IPM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|IPM_VALID"
assert_match "non-admin refused" "$(run_cobol "IPM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0