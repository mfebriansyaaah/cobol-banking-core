#!/usr/bin/env bash
# Credit insurance (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_credit_insurance

# Create a cost center.
create_out="$(run_cobol "CRI_CREATE|CRI-W16-1|InsuredA|TRADE|||admin@test.com")"
assert_match "CRI_CREATE ok" "$create_out" "SUCCESS\|CRI_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM credit_insurance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CRI_CREATE|CRI-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CRI_GET ok" "$(run_cobol "CRI_GET|${id}|||||admin@test.com")" "SUCCESS\|CRI_GET\|${id}\|CRI-W16-1"
assert_match "CRI_LIST ok" "$(run_cobol "CRI_LIST|||50|0||admin@test.com")" "CRI-W16-1"

# Allocate.
assert_match "CRI_CALC ok" "$(run_cobol "CRI_CALC|${id}|||||admin@test.com")" "SUCCESS\|CRI_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM credit_insurance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CRI_DELETE ok" "$(run_cobol "CRI_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CRI_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM credit_insurance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CRI_SUMMARY ok" "$(run_cobol "CRI_SUMMARY||||||admin@test.com")" "SUCCESS\|CRI_SUMMARY"
assert_match "CRI_AUDIT ok" "$(run_cobol "CRI_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CRI_AUDIT"
assert_match "CRI_VALIDATE ok" "$(run_cobol "CRI_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CRI_VALID"
assert_match "non-admin refused" "$(run_cobol "CRI_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0