#!/usr/bin/env bash
# Cooperative banking (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_cooperative_banking

# Create a cost center.
create_out="$(run_cobol "COB_CREATE|COB-W20-1|BankA|COOP|||admin@test.com")"
assert_match "COB_CREATE ok" "$create_out" "SUCCESS\|COB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM cooperative_banking WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "COB_CREATE|COB-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "COB_GET ok" "$(run_cobol "COB_GET|${id}|||||admin@test.com")" "SUCCESS\|COB_GET\|${id}\|COB-W20-1"
assert_match "COB_LIST ok" "$(run_cobol "COB_LIST|||50|0||admin@test.com")" "COB-W20-1"

# Allocate.
assert_match "COB_CALC ok" "$(run_cobol "COB_CALC|${id}|||||admin@test.com")" "SUCCESS\|COB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM cooperative_banking WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "COB_DELETE ok" "$(run_cobol "COB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|COB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM cooperative_banking WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "COB_SUMMARY ok" "$(run_cobol "COB_SUMMARY||||||admin@test.com")" "SUCCESS\|COB_SUMMARY"
assert_match "COB_AUDIT ok" "$(run_cobol "COB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|COB_AUDIT"
assert_match "COB_VALIDATE ok" "$(run_cobol "COB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|COB_VALID"
assert_match "non-admin refused" "$(run_cobol "COB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0