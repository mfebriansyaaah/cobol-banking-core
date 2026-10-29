#!/usr/bin/env bash
# Reopening item (Wave15) end-to-end DB tests via the COBOL binary.
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
db_reset_reopening_item

# Create a cost center.
create_out="$(run_cobol "REOP_CREATE|REOP-W15-1|AccountA|ACCOUNT|||admin@test.com")"
assert_match "REOP_CREATE ok" "$create_out" "SUCCESS\|REOP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM reopening_item WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "REOP_CREATE|REOP-W15-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "REOP_GET ok" "$(run_cobol "REOP_GET|${id}|||||admin@test.com")" "SUCCESS\|REOP_GET\|${id}\|REOP-W15-1"
assert_match "REOP_LIST ok" "$(run_cobol "REOP_LIST|||50|0||admin@test.com")" "REOP-W15-1"

# Allocate.
assert_match "REOP_CALC ok" "$(run_cobol "REOP_CALC|${id}|||||admin@test.com")" "SUCCESS\|REOP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM reopening_item WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "REOP_DELETE ok" "$(run_cobol "REOP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|REOP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM reopening_item WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "REOP_SUMMARY ok" "$(run_cobol "REOP_SUMMARY||||||admin@test.com")" "SUCCESS\|REOP_SUMMARY"
assert_match "REOP_AUDIT ok" "$(run_cobol "REOP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|REOP_AUDIT"
assert_match "REOP_VALIDATE ok" "$(run_cobol "REOP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|REOP_VALID"
assert_match "non-admin refused" "$(run_cobol "REOP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0