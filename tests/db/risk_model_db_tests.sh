#!/usr/bin/env bash
# Risk model (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_risk_model

# Create a cost center.
create_out="$(run_cobol "RSM_CREATE|RSM-W7-1|ModelA|VAR|||admin@test.com")"
assert_match "RSM_CREATE ok" "$create_out" "SUCCESS\|RSM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM risk_model WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RSM_CREATE|RSM-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RSM_GET ok" "$(run_cobol "RSM_GET|${id}|||||admin@test.com")" "SUCCESS\|RSM_GET\|${id}\|RSM-W7-1"
assert_match "RSM_LIST ok" "$(run_cobol "RSM_LIST|||50|0||admin@test.com")" "RSM-W7-1"

# Allocate.
assert_match "RSM_CALC ok" "$(run_cobol "RSM_CALC|${id}|||||admin@test.com")" "SUCCESS\|RSM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM risk_model WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RSM_DELETE ok" "$(run_cobol "RSM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RSM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM risk_model WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "RSM_SUMMARY ok" "$(run_cobol "RSM_SUMMARY||||||admin@test.com")" "SUCCESS\|RSM_SUMMARY"
assert_match "RSM_AUDIT ok" "$(run_cobol "RSM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RSM_AUDIT"
assert_match "RSM_VALIDATE ok" "$(run_cobol "RSM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RSM_VALID"
assert_match "non-admin refused" "$(run_cobol "RSM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0