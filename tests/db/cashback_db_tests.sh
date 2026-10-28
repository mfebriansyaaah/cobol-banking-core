#!/usr/bin/env bash
# Cashback (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_cashback

# Create a cost center.
create_out="$(run_cobol "CSB_CREATE|CSB-W8-1|CustomerA|PERCENT|||admin@test.com")"
assert_match "CSB_CREATE ok" "$create_out" "SUCCESS\|CSB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM cashback WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CSB_CREATE|CSB-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CSB_GET ok" "$(run_cobol "CSB_GET|${id}|||||admin@test.com")" "SUCCESS\|CSB_GET\|${id}\|CSB-W8-1"
assert_match "CSB_LIST ok" "$(run_cobol "CSB_LIST|||50|0||admin@test.com")" "CSB-W8-1"

# Allocate.
assert_match "CSB_CALC ok" "$(run_cobol "CSB_CALC|${id}|||||admin@test.com")" "SUCCESS\|CSB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM cashback WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CSB_DELETE ok" "$(run_cobol "CSB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CSB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM cashback WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CSB_SUMMARY ok" "$(run_cobol "CSB_SUMMARY||||||admin@test.com")" "SUCCESS\|CSB_SUMMARY"
assert_match "CSB_AUDIT ok" "$(run_cobol "CSB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CSB_AUDIT"
assert_match "CSB_VALIDATE ok" "$(run_cobol "CSB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CSB_VALID"
assert_match "non-admin refused" "$(run_cobol "CSB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0