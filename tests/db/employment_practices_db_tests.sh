#!/usr/bin/env bash
# Employment practices (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_employment_practices

# Create a cost center.
create_out="$(run_cobol "EPL_CREATE|EPL-W18-1|EmployerA|LIABILITY|||admin@test.com")"
assert_match "EPL_CREATE ok" "$create_out" "SUCCESS\|EPL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM employment_practices WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "EPL_CREATE|EPL-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "EPL_GET ok" "$(run_cobol "EPL_GET|${id}|||||admin@test.com")" "SUCCESS\|EPL_GET\|${id}\|EPL-W18-1"
assert_match "EPL_LIST ok" "$(run_cobol "EPL_LIST|||50|0||admin@test.com")" "EPL-W18-1"

# Allocate.
assert_match "EPL_CALC ok" "$(run_cobol "EPL_CALC|${id}|||||admin@test.com")" "SUCCESS\|EPL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM employment_practices WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "EPL_DELETE ok" "$(run_cobol "EPL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|EPL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM employment_practices WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "EPL_SUMMARY ok" "$(run_cobol "EPL_SUMMARY||||||admin@test.com")" "SUCCESS\|EPL_SUMMARY"
assert_match "EPL_AUDIT ok" "$(run_cobol "EPL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|EPL_AUDIT"
assert_match "EPL_VALIDATE ok" "$(run_cobol "EPL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|EPL_VALID"
assert_match "non-admin refused" "$(run_cobol "EPL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0