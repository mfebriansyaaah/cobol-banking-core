#!/usr/bin/env bash
# Account lock (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_account_lock

# Create a cost center.
create_out="$(run_cobol "ACL_CREATE|ACL-W8-1|AccountA|FRAUD|||admin@test.com")"
assert_match "ACL_CREATE ok" "$create_out" "SUCCESS\|ACL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM account_lock WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ACL_CREATE|ACL-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ACL_GET ok" "$(run_cobol "ACL_GET|${id}|||||admin@test.com")" "SUCCESS\|ACL_GET\|${id}\|ACL-W8-1"
assert_match "ACL_LIST ok" "$(run_cobol "ACL_LIST|||50|0||admin@test.com")" "ACL-W8-1"

# Allocate.
assert_match "ACL_CALC ok" "$(run_cobol "ACL_CALC|${id}|||||admin@test.com")" "SUCCESS\|ACL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM account_lock WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ACL_DELETE ok" "$(run_cobol "ACL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ACL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM account_lock WHERE id=${id};")" "^LOCKED$"

# Summary and audit.
assert_match "ACL_SUMMARY ok" "$(run_cobol "ACL_SUMMARY||||||admin@test.com")" "SUCCESS\|ACL_SUMMARY"
assert_match "ACL_AUDIT ok" "$(run_cobol "ACL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ACL_AUDIT"
assert_match "ACL_VALIDATE ok" "$(run_cobol "ACL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ACL_VALID"
assert_match "non-admin refused" "$(run_cobol "ACL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0