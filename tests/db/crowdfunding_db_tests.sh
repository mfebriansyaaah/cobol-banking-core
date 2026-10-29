#!/usr/bin/env bash
# Crowdfunding (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_crowdfunding

# Create a cost center.
create_out="$(run_cobol "CFD_CREATE|CFD-W16-1|ProjectA|REWARD|||admin@test.com")"
assert_match "CFD_CREATE ok" "$create_out" "SUCCESS\|CFD_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM crowdfunding WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CFD_CREATE|CFD-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CFD_GET ok" "$(run_cobol "CFD_GET|${id}|||||admin@test.com")" "SUCCESS\|CFD_GET\|${id}\|CFD-W16-1"
assert_match "CFD_LIST ok" "$(run_cobol "CFD_LIST|||50|0||admin@test.com")" "CFD-W16-1"

# Allocate.
assert_match "CFD_CALC ok" "$(run_cobol "CFD_CALC|${id}|||||admin@test.com")" "SUCCESS\|CFD_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM crowdfunding WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CFD_DELETE ok" "$(run_cobol "CFD_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CFD_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM crowdfunding WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CFD_SUMMARY ok" "$(run_cobol "CFD_SUMMARY||||||admin@test.com")" "SUCCESS\|CFD_SUMMARY"
assert_match "CFD_AUDIT ok" "$(run_cobol "CFD_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CFD_AUDIT"
assert_match "CFD_VALIDATE ok" "$(run_cobol "CFD_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CFD_VALID"
assert_match "non-admin refused" "$(run_cobol "CFD_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0