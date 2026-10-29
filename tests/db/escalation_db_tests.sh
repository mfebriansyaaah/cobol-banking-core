#!/usr/bin/env bash
# Escalation (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_escalation

# Create a cost center.
create_out="$(run_cobol "ESCL_CREATE|ESCL-W17-1|IssueA|ISSUE|||admin@test.com")"
assert_match "ESCL_CREATE ok" "$create_out" "SUCCESS\|ESCL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM escalation WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ESCL_CREATE|ESCL-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ESCL_GET ok" "$(run_cobol "ESCL_GET|${id}|||||admin@test.com")" "SUCCESS\|ESCL_GET\|${id}\|ESCL-W17-1"
assert_match "ESCL_LIST ok" "$(run_cobol "ESCL_LIST|||50|0||admin@test.com")" "ESCL-W17-1"

# Allocate.
assert_match "ESCL_CALC ok" "$(run_cobol "ESCL_CALC|${id}|||||admin@test.com")" "SUCCESS\|ESCL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM escalation WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ESCL_DELETE ok" "$(run_cobol "ESCL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ESCL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM escalation WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ESCL_SUMMARY ok" "$(run_cobol "ESCL_SUMMARY||||||admin@test.com")" "SUCCESS\|ESCL_SUMMARY"
assert_match "ESCL_AUDIT ok" "$(run_cobol "ESCL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ESCL_AUDIT"
assert_match "ESCL_VALIDATE ok" "$(run_cobol "ESCL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ESCL_VALID"
assert_match "non-admin refused" "$(run_cobol "ESCL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0