#!/usr/bin/env bash
# Direct lending (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_direct_lending

# Create a cost center.
create_out="$(run_cobol "DLL_CREATE|DLL-W12-1|BorrowerA|SENIOR|||admin@test.com")"
assert_match "DLL_CREATE ok" "$create_out" "SUCCESS\|DLL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM direct_lending WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DLL_CREATE|DLL-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DLL_GET ok" "$(run_cobol "DLL_GET|${id}|||||admin@test.com")" "SUCCESS\|DLL_GET\|${id}\|DLL-W12-1"
assert_match "DLL_LIST ok" "$(run_cobol "DLL_LIST|||50|0||admin@test.com")" "DLL-W12-1"

# Allocate.
assert_match "DLL_CALC ok" "$(run_cobol "DLL_CALC|${id}|||||admin@test.com")" "SUCCESS\|DLL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM direct_lending WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DLL_DELETE ok" "$(run_cobol "DLL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DLL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM direct_lending WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "DLL_SUMMARY ok" "$(run_cobol "DLL_SUMMARY||||||admin@test.com")" "SUCCESS\|DLL_SUMMARY"
assert_match "DLL_AUDIT ok" "$(run_cobol "DLL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DLL_AUDIT"
assert_match "DLL_VALIDATE ok" "$(run_cobol "DLL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DLL_VALID"
assert_match "non-admin refused" "$(run_cobol "DLL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0