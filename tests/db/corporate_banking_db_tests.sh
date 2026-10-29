#!/usr/bin/env bash
# Corporate banking (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_corporate_banking

# Create a cost center.
create_out="$(run_cobol "CPB_CREATE|CPB-W20-1|BankA|BUSINESS|||admin@test.com")"
assert_match "CPB_CREATE ok" "$create_out" "SUCCESS\|CPB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM corporate_banking WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CPB_CREATE|CPB-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CPB_GET ok" "$(run_cobol "CPB_GET|${id}|||||admin@test.com")" "SUCCESS\|CPB_GET\|${id}\|CPB-W20-1"
assert_match "CPB_LIST ok" "$(run_cobol "CPB_LIST|||50|0||admin@test.com")" "CPB-W20-1"

# Allocate.
assert_match "CPB_CALC ok" "$(run_cobol "CPB_CALC|${id}|||||admin@test.com")" "SUCCESS\|CPB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM corporate_banking WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CPB_DELETE ok" "$(run_cobol "CPB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CPB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM corporate_banking WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CPB_SUMMARY ok" "$(run_cobol "CPB_SUMMARY||||||admin@test.com")" "SUCCESS\|CPB_SUMMARY"
assert_match "CPB_AUDIT ok" "$(run_cobol "CPB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CPB_AUDIT"
assert_match "CPB_VALIDATE ok" "$(run_cobol "CPB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CPB_VALID"
assert_match "non-admin refused" "$(run_cobol "CPB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0