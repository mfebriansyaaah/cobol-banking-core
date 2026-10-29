#!/usr/bin/env bash
# Stock (Wave19) end-to-end DB tests via the COBOL binary.
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
db_reset_stock

# Create a cost center.
create_out="$(run_cobol "STK_CREATE|STK-W19-1|ItemA|FINISHED|||admin@test.com")"
assert_match "STK_CREATE ok" "$create_out" "SUCCESS\|STK_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM stock WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "STK_CREATE|STK-W19-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "STK_GET ok" "$(run_cobol "STK_GET|${id}|||||admin@test.com")" "SUCCESS\|STK_GET\|${id}\|STK-W19-1"
assert_match "STK_LIST ok" "$(run_cobol "STK_LIST|||50|0||admin@test.com")" "STK-W19-1"

# Allocate.
assert_match "STK_CALC ok" "$(run_cobol "STK_CALC|${id}|||||admin@test.com")" "SUCCESS\|STK_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM stock WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "STK_DELETE ok" "$(run_cobol "STK_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|STK_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM stock WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "STK_SUMMARY ok" "$(run_cobol "STK_SUMMARY||||||admin@test.com")" "SUCCESS\|STK_SUMMARY"
assert_match "STK_AUDIT ok" "$(run_cobol "STK_AUDIT|50|0||||admin@test.com")" "SUCCESS\|STK_AUDIT"
assert_match "STK_VALIDATE ok" "$(run_cobol "STK_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|STK_VALID"
assert_match "non-admin refused" "$(run_cobol "STK_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0