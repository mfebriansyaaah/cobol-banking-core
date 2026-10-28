#!/usr/bin/env bash
# Debt recovery (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_debt_recovery

# Create a cost center.
create_out="$(run_cobol "DRC_CREATE|DRC-W7-1|DebtorA|SETTLEMENT|||admin@test.com")"
assert_match "DRC_CREATE ok" "$create_out" "SUCCESS\|DRC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM debt_recovery WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DRC_CREATE|DRC-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DRC_GET ok" "$(run_cobol "DRC_GET|${id}|||||admin@test.com")" "SUCCESS\|DRC_GET\|${id}\|DRC-W7-1"
assert_match "DRC_LIST ok" "$(run_cobol "DRC_LIST|||50|0||admin@test.com")" "DRC-W7-1"

# Allocate.
assert_match "DRC_CALC ok" "$(run_cobol "DRC_CALC|${id}|||||admin@test.com")" "SUCCESS\|DRC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM debt_recovery WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DRC_DELETE ok" "$(run_cobol "DRC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DRC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM debt_recovery WHERE id=${id};")" "^RECOVERED$"

# Summary and audit.
assert_match "DRC_SUMMARY ok" "$(run_cobol "DRC_SUMMARY||||||admin@test.com")" "SUCCESS\|DRC_SUMMARY"
assert_match "DRC_AUDIT ok" "$(run_cobol "DRC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DRC_AUDIT"
assert_match "DRC_VALIDATE ok" "$(run_cobol "DRC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DRC_VALID"
assert_match "non-admin refused" "$(run_cobol "DRC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0