#!/usr/bin/env bash
# Personal loan (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_personal_loan

# Create a cost center.
create_out="$(run_cobol "PLN_CREATE|PLN-W16-1|BorrowerA|UNSECURED|||admin@test.com")"
assert_match "PLN_CREATE ok" "$create_out" "SUCCESS\|PLN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM personal_loan WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PLN_CREATE|PLN-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PLN_GET ok" "$(run_cobol "PLN_GET|${id}|||||admin@test.com")" "SUCCESS\|PLN_GET\|${id}\|PLN-W16-1"
assert_match "PLN_LIST ok" "$(run_cobol "PLN_LIST|||50|0||admin@test.com")" "PLN-W16-1"

# Allocate.
assert_match "PLN_CALC ok" "$(run_cobol "PLN_CALC|${id}|||||admin@test.com")" "SUCCESS\|PLN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM personal_loan WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PLN_DELETE ok" "$(run_cobol "PLN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PLN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM personal_loan WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PLN_SUMMARY ok" "$(run_cobol "PLN_SUMMARY||||||admin@test.com")" "SUCCESS\|PLN_SUMMARY"
assert_match "PLN_AUDIT ok" "$(run_cobol "PLN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PLN_AUDIT"
assert_match "PLN_VALIDATE ok" "$(run_cobol "PLN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PLN_VALID"
assert_match "non-admin refused" "$(run_cobol "PLN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0