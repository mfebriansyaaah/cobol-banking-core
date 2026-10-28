#!/usr/bin/env bash
# Mutual fund (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_mutual_fund

# Create a cost center.
create_out="$(run_cobol "MFD_CREATE|MFD-W12-1|FundA|OPEN_ENDED|||admin@test.com")"
assert_match "MFD_CREATE ok" "$create_out" "SUCCESS\|MFD_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM mutual_fund WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MFD_CREATE|MFD-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MFD_GET ok" "$(run_cobol "MFD_GET|${id}|||||admin@test.com")" "SUCCESS\|MFD_GET\|${id}\|MFD-W12-1"
assert_match "MFD_LIST ok" "$(run_cobol "MFD_LIST|||50|0||admin@test.com")" "MFD-W12-1"

# Allocate.
assert_match "MFD_CALC ok" "$(run_cobol "MFD_CALC|${id}|||||admin@test.com")" "SUCCESS\|MFD_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM mutual_fund WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MFD_DELETE ok" "$(run_cobol "MFD_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MFD_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM mutual_fund WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MFD_SUMMARY ok" "$(run_cobol "MFD_SUMMARY||||||admin@test.com")" "SUCCESS\|MFD_SUMMARY"
assert_match "MFD_AUDIT ok" "$(run_cobol "MFD_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MFD_AUDIT"
assert_match "MFD_VALIDATE ok" "$(run_cobol "MFD_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MFD_VALID"
assert_match "non-admin refused" "$(run_cobol "MFD_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0