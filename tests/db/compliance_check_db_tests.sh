#!/usr/bin/env bash
# Compliance check (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_compliance_check

# Create a cost center.
create_out="$(run_cobol "CMP_CREATE|CMP-W17-1|EntityA|AML|||admin@test.com")"
assert_match "CMP_CREATE ok" "$create_out" "SUCCESS\|CMP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM compliance_check WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CMP_CREATE|CMP-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CMP_GET ok" "$(run_cobol "CMP_GET|${id}|||||admin@test.com")" "SUCCESS\|CMP_GET\|${id}\|CMP-W17-1"
assert_match "CMP_LIST ok" "$(run_cobol "CMP_LIST|||50|0||admin@test.com")" "CMP-W17-1"

# Allocate.
assert_match "CMP_CALC ok" "$(run_cobol "CMP_CALC|${id}|||||admin@test.com")" "SUCCESS\|CMP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM compliance_check WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CMP_DELETE ok" "$(run_cobol "CMP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CMP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM compliance_check WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CMP_SUMMARY ok" "$(run_cobol "CMP_SUMMARY||||||admin@test.com")" "SUCCESS\|CMP_SUMMARY"
assert_match "CMP_AUDIT ok" "$(run_cobol "CMP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CMP_AUDIT"
assert_match "CMP_VALIDATE ok" "$(run_cobol "CMP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CMP_VALID"
assert_match "non-admin refused" "$(run_cobol "CMP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0