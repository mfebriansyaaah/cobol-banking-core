#!/usr/bin/env bash
# Home insurance (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_home_insurance

# Create a cost center.
create_out="$(run_cobol "HOM_CREATE|HOM-W18-1|PolicyholderA|STRUCTURE|||admin@test.com")"
assert_match "HOM_CREATE ok" "$create_out" "SUCCESS\|HOM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM home_insurance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "HOM_CREATE|HOM-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "HOM_GET ok" "$(run_cobol "HOM_GET|${id}|||||admin@test.com")" "SUCCESS\|HOM_GET\|${id}\|HOM-W18-1"
assert_match "HOM_LIST ok" "$(run_cobol "HOM_LIST|||50|0||admin@test.com")" "HOM-W18-1"

# Allocate.
assert_match "HOM_CALC ok" "$(run_cobol "HOM_CALC|${id}|||||admin@test.com")" "SUCCESS\|HOM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM home_insurance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "HOM_DELETE ok" "$(run_cobol "HOM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|HOM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM home_insurance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "HOM_SUMMARY ok" "$(run_cobol "HOM_SUMMARY||||||admin@test.com")" "SUCCESS\|HOM_SUMMARY"
assert_match "HOM_AUDIT ok" "$(run_cobol "HOM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|HOM_AUDIT"
assert_match "HOM_VALIDATE ok" "$(run_cobol "HOM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|HOM_VALID"
assert_match "non-admin refused" "$(run_cobol "HOM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0