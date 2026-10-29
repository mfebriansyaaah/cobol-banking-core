#!/usr/bin/env bash
# Investment banking (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_investment_banking

# Create a cost center.
create_out="$(run_cobol "IVB_CREATE|IVB-W20-1|BankA|CAPITAL_MARKETS|||admin@test.com")"
assert_match "IVB_CREATE ok" "$create_out" "SUCCESS\|IVB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM investment_banking WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "IVB_CREATE|IVB-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "IVB_GET ok" "$(run_cobol "IVB_GET|${id}|||||admin@test.com")" "SUCCESS\|IVB_GET\|${id}\|IVB-W20-1"
assert_match "IVB_LIST ok" "$(run_cobol "IVB_LIST|||50|0||admin@test.com")" "IVB-W20-1"

# Allocate.
assert_match "IVB_CALC ok" "$(run_cobol "IVB_CALC|${id}|||||admin@test.com")" "SUCCESS\|IVB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM investment_banking WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "IVB_DELETE ok" "$(run_cobol "IVB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|IVB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM investment_banking WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "IVB_SUMMARY ok" "$(run_cobol "IVB_SUMMARY||||||admin@test.com")" "SUCCESS\|IVB_SUMMARY"
assert_match "IVB_AUDIT ok" "$(run_cobol "IVB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|IVB_AUDIT"
assert_match "IVB_VALIDATE ok" "$(run_cobol "IVB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|IVB_VALID"
assert_match "non-admin refused" "$(run_cobol "IVB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0