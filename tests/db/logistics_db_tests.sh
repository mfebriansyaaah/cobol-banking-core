#!/usr/bin/env bash
# Logistics (Wave19) end-to-end DB tests via the COBOL binary.
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
db_reset_logistics

# Create a cost center.
create_out="$(run_cobol "LOG2_CREATE|LOG2-W19-1|LogisticsA|ROAD|||admin@test.com")"
assert_match "LOG2_CREATE ok" "$create_out" "SUCCESS\|LOG2_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM logistics WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "LOG2_CREATE|LOG2-W19-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "LOG2_GET ok" "$(run_cobol "LOG2_GET|${id}|||||admin@test.com")" "SUCCESS\|LOG2_GET\|${id}\|LOG2-W19-1"
assert_match "LOG2_LIST ok" "$(run_cobol "LOG2_LIST|||50|0||admin@test.com")" "LOG2-W19-1"

# Allocate.
assert_match "LOG2_CALC ok" "$(run_cobol "LOG2_CALC|${id}|||||admin@test.com")" "SUCCESS\|LOG2_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM logistics WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "LOG2_DELETE ok" "$(run_cobol "LOG2_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|LOG2_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM logistics WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "LOG2_SUMMARY ok" "$(run_cobol "LOG2_SUMMARY||||||admin@test.com")" "SUCCESS\|LOG2_SUMMARY"
assert_match "LOG2_AUDIT ok" "$(run_cobol "LOG2_AUDIT|50|0||||admin@test.com")" "SUCCESS\|LOG2_AUDIT"
assert_match "LOG2_VALIDATE ok" "$(run_cobol "LOG2_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|LOG2_VALID"
assert_match "non-admin refused" "$(run_cobol "LOG2_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0