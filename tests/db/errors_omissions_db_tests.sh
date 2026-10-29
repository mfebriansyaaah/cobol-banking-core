#!/usr/bin/env bash
# Errors omissions (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_errors_omissions

# Create a cost center.
create_out="$(run_cobol "EAO_CREATE|EAO-W18-1|ProfessionalA|PROFESSIONAL|||admin@test.com")"
assert_match "EAO_CREATE ok" "$create_out" "SUCCESS\|EAO_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM errors_omissions WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "EAO_CREATE|EAO-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "EAO_GET ok" "$(run_cobol "EAO_GET|${id}|||||admin@test.com")" "SUCCESS\|EAO_GET\|${id}\|EAO-W18-1"
assert_match "EAO_LIST ok" "$(run_cobol "EAO_LIST|||50|0||admin@test.com")" "EAO-W18-1"

# Allocate.
assert_match "EAO_CALC ok" "$(run_cobol "EAO_CALC|${id}|||||admin@test.com")" "SUCCESS\|EAO_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM errors_omissions WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "EAO_DELETE ok" "$(run_cobol "EAO_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|EAO_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM errors_omissions WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "EAO_SUMMARY ok" "$(run_cobol "EAO_SUMMARY||||||admin@test.com")" "SUCCESS\|EAO_SUMMARY"
assert_match "EAO_AUDIT ok" "$(run_cobol "EAO_AUDIT|50|0||||admin@test.com")" "SUCCESS\|EAO_AUDIT"
assert_match "EAO_VALIDATE ok" "$(run_cobol "EAO_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|EAO_VALID"
assert_match "non-admin refused" "$(run_cobol "EAO_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0