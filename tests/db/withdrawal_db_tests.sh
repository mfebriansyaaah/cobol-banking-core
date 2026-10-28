#!/usr/bin/env bash
# Withdrawal (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_withdrawal

# Create a cost center.
create_out="$(run_cobol "WDL_CREATE|WDL-W13-1|AccountA|ATM|||admin@test.com")"
assert_match "WDL_CREATE ok" "$create_out" "SUCCESS\|WDL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM withdrawal WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "WDL_CREATE|WDL-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "WDL_GET ok" "$(run_cobol "WDL_GET|${id}|||||admin@test.com")" "SUCCESS\|WDL_GET\|${id}\|WDL-W13-1"
assert_match "WDL_LIST ok" "$(run_cobol "WDL_LIST|||50|0||admin@test.com")" "WDL-W13-1"

# Allocate.
assert_match "WDL_CALC ok" "$(run_cobol "WDL_CALC|${id}|||||admin@test.com")" "SUCCESS\|WDL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM withdrawal WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "WDL_DELETE ok" "$(run_cobol "WDL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|WDL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM withdrawal WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "WDL_SUMMARY ok" "$(run_cobol "WDL_SUMMARY||||||admin@test.com")" "SUCCESS\|WDL_SUMMARY"
assert_match "WDL_AUDIT ok" "$(run_cobol "WDL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|WDL_AUDIT"
assert_match "WDL_VALIDATE ok" "$(run_cobol "WDL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|WDL_VALID"
assert_match "non-admin refused" "$(run_cobol "WDL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0