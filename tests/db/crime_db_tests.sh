#!/usr/bin/env bash
# Crime (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_crime

# Create a cost center.
create_out="$(run_cobol "CRIM_CREATE|CRIM-W18-1|InsuredA|COMMERCIAL|||admin@test.com")"
assert_match "CRIM_CREATE ok" "$create_out" "SUCCESS\|CRIM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM crime WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CRIM_CREATE|CRIM-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CRIM_GET ok" "$(run_cobol "CRIM_GET|${id}|||||admin@test.com")" "SUCCESS\|CRIM_GET\|${id}\|CRIM-W18-1"
assert_match "CRIM_LIST ok" "$(run_cobol "CRIM_LIST|||50|0||admin@test.com")" "CRIM-W18-1"

# Allocate.
assert_match "CRIM_CALC ok" "$(run_cobol "CRIM_CALC|${id}|||||admin@test.com")" "SUCCESS\|CRIM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM crime WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CRIM_DELETE ok" "$(run_cobol "CRIM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CRIM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM crime WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CRIM_SUMMARY ok" "$(run_cobol "CRIM_SUMMARY||||||admin@test.com")" "SUCCESS\|CRIM_SUMMARY"
assert_match "CRIM_AUDIT ok" "$(run_cobol "CRIM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CRIM_AUDIT"
assert_match "CRIM_VALIDATE ok" "$(run_cobol "CRIM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CRIM_VALID"
assert_match "non-admin refused" "$(run_cobol "CRIM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0