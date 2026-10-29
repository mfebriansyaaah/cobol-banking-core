#!/usr/bin/env bash
# Casualty insurance (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_casualty_insurance

# Create a cost center.
create_out="$(run_cobol "CSL_CREATE|CSL-W18-1|PolicyholderA|GENERAL|||admin@test.com")"
assert_match "CSL_CREATE ok" "$create_out" "SUCCESS\|CSL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM casualty_insurance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CSL_CREATE|CSL-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CSL_GET ok" "$(run_cobol "CSL_GET|${id}|||||admin@test.com")" "SUCCESS\|CSL_GET\|${id}\|CSL-W18-1"
assert_match "CSL_LIST ok" "$(run_cobol "CSL_LIST|||50|0||admin@test.com")" "CSL-W18-1"

# Allocate.
assert_match "CSL_CALC ok" "$(run_cobol "CSL_CALC|${id}|||||admin@test.com")" "SUCCESS\|CSL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM casualty_insurance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CSL_DELETE ok" "$(run_cobol "CSL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CSL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM casualty_insurance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CSL_SUMMARY ok" "$(run_cobol "CSL_SUMMARY||||||admin@test.com")" "SUCCESS\|CSL_SUMMARY"
assert_match "CSL_AUDIT ok" "$(run_cobol "CSL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CSL_AUDIT"
assert_match "CSL_VALIDATE ok" "$(run_cobol "CSL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CSL_VALID"
assert_match "non-admin refused" "$(run_cobol "CSL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0