#!/usr/bin/env bash
# Mobile banking (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_mobile_banking

# Create a cost center.
create_out="$(run_cobol "MBK_CREATE|MBK-W20-1|BankA|APP|||admin@test.com")"
assert_match "MBK_CREATE ok" "$create_out" "SUCCESS\|MBK_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM mobile_banking WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MBK_CREATE|MBK-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MBK_GET ok" "$(run_cobol "MBK_GET|${id}|||||admin@test.com")" "SUCCESS\|MBK_GET\|${id}\|MBK-W20-1"
assert_match "MBK_LIST ok" "$(run_cobol "MBK_LIST|||50|0||admin@test.com")" "MBK-W20-1"

# Allocate.
assert_match "MBK_CALC ok" "$(run_cobol "MBK_CALC|${id}|||||admin@test.com")" "SUCCESS\|MBK_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM mobile_banking WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MBK_DELETE ok" "$(run_cobol "MBK_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MBK_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM mobile_banking WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MBK_SUMMARY ok" "$(run_cobol "MBK_SUMMARY||||||admin@test.com")" "SUCCESS\|MBK_SUMMARY"
assert_match "MBK_AUDIT ok" "$(run_cobol "MBK_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MBK_AUDIT"
assert_match "MBK_VALIDATE ok" "$(run_cobol "MBK_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MBK_VALID"
assert_match "non-admin refused" "$(run_cobol "MBK_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0