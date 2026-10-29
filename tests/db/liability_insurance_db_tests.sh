#!/usr/bin/env bash
# Liability insurance (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_liability_insurance

# Create a cost center.
create_out="$(run_cobol "LIB_CREATE|LIB-W18-1|PolicyholderA|PUBLIC|||admin@test.com")"
assert_match "LIB_CREATE ok" "$create_out" "SUCCESS\|LIB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM liability_insurance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "LIB_CREATE|LIB-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "LIB_GET ok" "$(run_cobol "LIB_GET|${id}|||||admin@test.com")" "SUCCESS\|LIB_GET\|${id}\|LIB-W18-1"
assert_match "LIB_LIST ok" "$(run_cobol "LIB_LIST|||50|0||admin@test.com")" "LIB-W18-1"

# Allocate.
assert_match "LIB_CALC ok" "$(run_cobol "LIB_CALC|${id}|||||admin@test.com")" "SUCCESS\|LIB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM liability_insurance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "LIB_DELETE ok" "$(run_cobol "LIB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|LIB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM liability_insurance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "LIB_SUMMARY ok" "$(run_cobol "LIB_SUMMARY||||||admin@test.com")" "SUCCESS\|LIB_SUMMARY"
assert_match "LIB_AUDIT ok" "$(run_cobol "LIB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|LIB_AUDIT"
assert_match "LIB_VALIDATE ok" "$(run_cobol "LIB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|LIB_VALID"
assert_match "non-admin refused" "$(run_cobol "LIB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0