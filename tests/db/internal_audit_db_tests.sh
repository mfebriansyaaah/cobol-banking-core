#!/usr/bin/env bash
# Internal audit (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_internal_audit

# Create a cost center.
create_out="$(run_cobol "INA_CREATE|INA-W7-1|AuditA|PROCESS|||admin@test.com")"
assert_match "INA_CREATE ok" "$create_out" "SUCCESS\|INA_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM internal_audit WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "INA_CREATE|INA-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "INA_GET ok" "$(run_cobol "INA_GET|${id}|||||admin@test.com")" "SUCCESS\|INA_GET\|${id}\|INA-W7-1"
assert_match "INA_LIST ok" "$(run_cobol "INA_LIST|||50|0||admin@test.com")" "INA-W7-1"

# Allocate.
assert_match "INA_CALC ok" "$(run_cobol "INA_CALC|${id}|||||admin@test.com")" "SUCCESS\|INA_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM internal_audit WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "INA_DELETE ok" "$(run_cobol "INA_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|INA_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM internal_audit WHERE id=${id};")" "^COMPLETED$"

# Summary and audit.
assert_match "INA_SUMMARY ok" "$(run_cobol "INA_SUMMARY||||||admin@test.com")" "SUCCESS\|INA_SUMMARY"
assert_match "INA_AUDIT ok" "$(run_cobol "INA_AUDIT|50|0||||admin@test.com")" "SUCCESS\|INA_AUDIT"
assert_match "INA_VALIDATE ok" "$(run_cobol "INA_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|INA_VALID"
assert_match "non-admin refused" "$(run_cobol "INA_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0