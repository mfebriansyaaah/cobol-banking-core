#!/usr/bin/env bash
# Factoring company (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_factoring_company

# Create a cost center.
create_out="$(run_cobol "FCOM_CREATE|FCOM-W20-1|FactoringA|RECEIVABLES|||admin@test.com")"
assert_match "FCOM_CREATE ok" "$create_out" "SUCCESS\|FCOM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM factoring_company WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FCOM_CREATE|FCOM-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FCOM_GET ok" "$(run_cobol "FCOM_GET|${id}|||||admin@test.com")" "SUCCESS\|FCOM_GET\|${id}\|FCOM-W20-1"
assert_match "FCOM_LIST ok" "$(run_cobol "FCOM_LIST|||50|0||admin@test.com")" "FCOM-W20-1"

# Allocate.
assert_match "FCOM_CALC ok" "$(run_cobol "FCOM_CALC|${id}|||||admin@test.com")" "SUCCESS\|FCOM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM factoring_company WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FCOM_DELETE ok" "$(run_cobol "FCOM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FCOM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM factoring_company WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "FCOM_SUMMARY ok" "$(run_cobol "FCOM_SUMMARY||||||admin@test.com")" "SUCCESS\|FCOM_SUMMARY"
assert_match "FCOM_AUDIT ok" "$(run_cobol "FCOM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FCOM_AUDIT"
assert_match "FCOM_VALIDATE ok" "$(run_cobol "FCOM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FCOM_VALID"
assert_match "non-admin refused" "$(run_cobol "FCOM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0