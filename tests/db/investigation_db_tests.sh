#!/usr/bin/env bash
# Investigation (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_investigation

# Create a cost center.
create_out="$(run_cobol "INV_CREATE|INV-W7-1|CaseA|FRAUD|||admin@test.com")"
assert_match "INV_CREATE ok" "$create_out" "SUCCESS\|INV_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM investigation WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "INV_CREATE|INV-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "INV_GET ok" "$(run_cobol "INV_GET|${id}|||||admin@test.com")" "SUCCESS\|INV_GET\|${id}\|INV-W7-1"
assert_match "INV_LIST ok" "$(run_cobol "INV_LIST|||50|0||admin@test.com")" "INV-W7-1"

# Allocate.
assert_match "INV_CALC ok" "$(run_cobol "INV_CALC|${id}|||||admin@test.com")" "SUCCESS\|INV_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM investigation WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "INV_DELETE ok" "$(run_cobol "INV_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|INV_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM investigation WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "INV_SUMMARY ok" "$(run_cobol "INV_SUMMARY||||||admin@test.com")" "SUCCESS\|INV_SUMMARY"
assert_match "INV_AUDIT ok" "$(run_cobol "INV_AUDIT|50|0||||admin@test.com")" "SUCCESS\|INV_AUDIT"
assert_match "INV_VALIDATE ok" "$(run_cobol "INV_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|INV_VALID"
assert_match "non-admin refused" "$(run_cobol "INV_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0