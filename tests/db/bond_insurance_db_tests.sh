#!/usr/bin/env bash
# Bond insurance (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_bond_insurance

# Create a cost center.
create_out="$(run_cobol "BNI_CREATE|BNI-W18-1|BondholderA|FIDELITY|||admin@test.com")"
assert_match "BNI_CREATE ok" "$create_out" "SUCCESS\|BNI_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM bond_insurance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BNI_CREATE|BNI-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BNI_GET ok" "$(run_cobol "BNI_GET|${id}|||||admin@test.com")" "SUCCESS\|BNI_GET\|${id}\|BNI-W18-1"
assert_match "BNI_LIST ok" "$(run_cobol "BNI_LIST|||50|0||admin@test.com")" "BNI-W18-1"

# Allocate.
assert_match "BNI_CALC ok" "$(run_cobol "BNI_CALC|${id}|||||admin@test.com")" "SUCCESS\|BNI_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM bond_insurance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "BNI_DELETE ok" "$(run_cobol "BNI_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|BNI_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM bond_insurance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "BNI_SUMMARY ok" "$(run_cobol "BNI_SUMMARY||||||admin@test.com")" "SUCCESS\|BNI_SUMMARY"
assert_match "BNI_AUDIT ok" "$(run_cobol "BNI_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BNI_AUDIT"
assert_match "BNI_VALIDATE ok" "$(run_cobol "BNI_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BNI_VALID"
assert_match "non-admin refused" "$(run_cobol "BNI_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0