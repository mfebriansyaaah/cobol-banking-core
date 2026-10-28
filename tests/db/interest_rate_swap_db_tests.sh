#!/usr/bin/env bash
# Interest rate swap (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_interest_rate_swap

# Create a cost center.
create_out="$(run_cobol "IRS_CREATE|IRS-W9-1|CounterpartyA|IRS|||admin@test.com")"
assert_match "IRS_CREATE ok" "$create_out" "SUCCESS\|IRS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM interest_rate_swap WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "IRS_CREATE|IRS-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "IRS_GET ok" "$(run_cobol "IRS_GET|${id}|||||admin@test.com")" "SUCCESS\|IRS_GET\|${id}\|IRS-W9-1"
assert_match "IRS_LIST ok" "$(run_cobol "IRS_LIST|||50|0||admin@test.com")" "IRS-W9-1"

# Allocate.
assert_match "IRS_CALC ok" "$(run_cobol "IRS_CALC|${id}|||||admin@test.com")" "SUCCESS\|IRS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM interest_rate_swap WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "IRS_DELETE ok" "$(run_cobol "IRS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|IRS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM interest_rate_swap WHERE id=${id};")" "^MATURED$"

# Summary and audit.
assert_match "IRS_SUMMARY ok" "$(run_cobol "IRS_SUMMARY||||||admin@test.com")" "SUCCESS\|IRS_SUMMARY"
assert_match "IRS_AUDIT ok" "$(run_cobol "IRS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|IRS_AUDIT"
assert_match "IRS_VALIDATE ok" "$(run_cobol "IRS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|IRS_VALID"
assert_match "non-admin refused" "$(run_cobol "IRS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0