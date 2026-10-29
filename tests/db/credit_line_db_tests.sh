#!/usr/bin/env bash
# Credit line (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_credit_line

# Create a cost center.
create_out="$(run_cobol "CLN_CREATE|CLN-W16-1|BorrowerA|REVOLVING|||admin@test.com")"
assert_match "CLN_CREATE ok" "$create_out" "SUCCESS\|CLN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM credit_line WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CLN_CREATE|CLN-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CLN_GET ok" "$(run_cobol "CLN_GET|${id}|||||admin@test.com")" "SUCCESS\|CLN_GET\|${id}\|CLN-W16-1"
assert_match "CLN_LIST ok" "$(run_cobol "CLN_LIST|||50|0||admin@test.com")" "CLN-W16-1"

# Allocate.
assert_match "CLN_CALC ok" "$(run_cobol "CLN_CALC|${id}|||||admin@test.com")" "SUCCESS\|CLN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM credit_line WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CLN_DELETE ok" "$(run_cobol "CLN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CLN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM credit_line WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CLN_SUMMARY ok" "$(run_cobol "CLN_SUMMARY||||||admin@test.com")" "SUCCESS\|CLN_SUMMARY"
assert_match "CLN_AUDIT ok" "$(run_cobol "CLN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CLN_AUDIT"
assert_match "CLN_VALIDATE ok" "$(run_cobol "CLN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CLN_VALID"
assert_match "non-admin refused" "$(run_cobol "CLN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0