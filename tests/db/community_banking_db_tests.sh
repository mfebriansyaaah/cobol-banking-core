#!/usr/bin/env bash
# Community banking (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_community_banking

# Create a cost center.
create_out="$(run_cobol "CMBC_CREATE|CMBC-W20-1|BankA|LOCAL|||admin@test.com")"
assert_match "CMBC_CREATE ok" "$create_out" "SUCCESS\|CMBC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM community_banking WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CMBC_CREATE|CMBC-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CMBC_GET ok" "$(run_cobol "CMBC_GET|${id}|||||admin@test.com")" "SUCCESS\|CMBC_GET\|${id}\|CMBC-W20-1"
assert_match "CMBC_LIST ok" "$(run_cobol "CMBC_LIST|||50|0||admin@test.com")" "CMBC-W20-1"

# Allocate.
assert_match "CMBC_CALC ok" "$(run_cobol "CMBC_CALC|${id}|||||admin@test.com")" "SUCCESS\|CMBC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM community_banking WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CMBC_DELETE ok" "$(run_cobol "CMBC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CMBC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM community_banking WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CMBC_SUMMARY ok" "$(run_cobol "CMBC_SUMMARY||||||admin@test.com")" "SUCCESS\|CMBC_SUMMARY"
assert_match "CMBC_AUDIT ok" "$(run_cobol "CMBC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CMBC_AUDIT"
assert_match "CMBC_VALIDATE ok" "$(run_cobol "CMBC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CMBC_VALID"
assert_match "non-admin refused" "$(run_cobol "CMBC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0