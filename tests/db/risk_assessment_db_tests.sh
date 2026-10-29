#!/usr/bin/env bash
# Risk assessment (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_risk_assessment

# Create a cost center.
create_out="$(run_cobol "RSA_CREATE|RSA-W17-1|EntityA|OPERATIONAL|||admin@test.com")"
assert_match "RSA_CREATE ok" "$create_out" "SUCCESS\|RSA_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM risk_assessment WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RSA_CREATE|RSA-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RSA_GET ok" "$(run_cobol "RSA_GET|${id}|||||admin@test.com")" "SUCCESS\|RSA_GET\|${id}\|RSA-W17-1"
assert_match "RSA_LIST ok" "$(run_cobol "RSA_LIST|||50|0||admin@test.com")" "RSA-W17-1"

# Allocate.
assert_match "RSA_CALC ok" "$(run_cobol "RSA_CALC|${id}|||||admin@test.com")" "SUCCESS\|RSA_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM risk_assessment WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RSA_DELETE ok" "$(run_cobol "RSA_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RSA_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM risk_assessment WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "RSA_SUMMARY ok" "$(run_cobol "RSA_SUMMARY||||||admin@test.com")" "SUCCESS\|RSA_SUMMARY"
assert_match "RSA_AUDIT ok" "$(run_cobol "RSA_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RSA_AUDIT"
assert_match "RSA_VALIDATE ok" "$(run_cobol "RSA_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RSA_VALID"
assert_match "non-admin refused" "$(run_cobol "RSA_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0