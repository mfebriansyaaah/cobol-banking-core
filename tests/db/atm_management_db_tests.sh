#!/usr/bin/env bash
# ATM management (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_atm_management

# Create a cost center.
create_out="$(run_cobol "ATM_CREATE|ATM-W6-1|ATMA|STANDALONE|||admin@test.com")"
assert_match "ATM_CREATE ok" "$create_out" "SUCCESS\|ATM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM atm_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ATM_CREATE|ATM-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ATM_GET ok" "$(run_cobol "ATM_GET|${id}|||||admin@test.com")" "SUCCESS\|ATM_GET\|${id}\|ATM-W6-1"
assert_match "ATM_LIST ok" "$(run_cobol "ATM_LIST|||50|0||admin@test.com")" "ATM-W6-1"

# Allocate.
assert_match "ATM_CALC ok" "$(run_cobol "ATM_CALC|${id}|||||admin@test.com")" "SUCCESS\|ATM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM atm_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ATM_DELETE ok" "$(run_cobol "ATM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ATM_DELETE"
assert_match "removed persisted" "$(db_query "SELECT status FROM atm_management WHERE id=${id};")" "^REMOVED$"

# Summary and audit.
assert_match "ATM_SUMMARY ok" "$(run_cobol "ATM_SUMMARY||||||admin@test.com")" "SUCCESS\|ATM_SUMMARY"
assert_match "ATM_AUDIT ok" "$(run_cobol "ATM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ATM_AUDIT"
assert_match "ATM_VALIDATE ok" "$(run_cobol "ATM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ATM_VALID"
assert_match "non-admin refused" "$(run_cobol "ATM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0