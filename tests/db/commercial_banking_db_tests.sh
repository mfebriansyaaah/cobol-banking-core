#!/usr/bin/env bash
# Commercial banking (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_commercial_banking

# Create a cost center.
create_out="$(run_cobol "CMB_CREATE|CMB-W20-1|BankA|SME|||admin@test.com")"
assert_match "CMB_CREATE ok" "$create_out" "SUCCESS\|CMB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM commercial_banking WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CMB_CREATE|CMB-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CMB_GET ok" "$(run_cobol "CMB_GET|${id}|||||admin@test.com")" "SUCCESS\|CMB_GET\|${id}\|CMB-W20-1"
assert_match "CMB_LIST ok" "$(run_cobol "CMB_LIST|||50|0||admin@test.com")" "CMB-W20-1"

# Allocate.
assert_match "CMB_CALC ok" "$(run_cobol "CMB_CALC|${id}|||||admin@test.com")" "SUCCESS\|CMB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM commercial_banking WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CMB_DELETE ok" "$(run_cobol "CMB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CMB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM commercial_banking WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CMB_SUMMARY ok" "$(run_cobol "CMB_SUMMARY||||||admin@test.com")" "SUCCESS\|CMB_SUMMARY"
assert_match "CMB_AUDIT ok" "$(run_cobol "CMB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CMB_AUDIT"
assert_match "CMB_VALIDATE ok" "$(run_cobol "CMB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CMB_VALID"
assert_match "non-admin refused" "$(run_cobol "CMB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0