#!/usr/bin/env bash
# Employer liability (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_employer_liability

# Create a cost center.
create_out="$(run_cobol "EMLI_CREATE|EMLI-W18-1|EmployerA|WORKERS_COMP|||admin@test.com")"
assert_match "EMLI_CREATE ok" "$create_out" "SUCCESS\|EMLI_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM employer_liability WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "EMLI_CREATE|EMLI-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "EMLI_GET ok" "$(run_cobol "EMLI_GET|${id}|||||admin@test.com")" "SUCCESS\|EMLI_GET\|${id}\|EMLI-W18-1"
assert_match "EMLI_LIST ok" "$(run_cobol "EMLI_LIST|||50|0||admin@test.com")" "EMLI-W18-1"

# Allocate.
assert_match "EMLI_CALC ok" "$(run_cobol "EMLI_CALC|${id}|||||admin@test.com")" "SUCCESS\|EMLI_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM employer_liability WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "EMLI_DELETE ok" "$(run_cobol "EMLI_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|EMLI_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM employer_liability WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "EMLI_SUMMARY ok" "$(run_cobol "EMLI_SUMMARY||||||admin@test.com")" "SUCCESS\|EMLI_SUMMARY"
assert_match "EMLI_AUDIT ok" "$(run_cobol "EMLI_AUDIT|50|0||||admin@test.com")" "SUCCESS\|EMLI_AUDIT"
assert_match "EMLI_VALIDATE ok" "$(run_cobol "EMLI_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|EMLI_VALID"
assert_match "non-admin refused" "$(run_cobol "EMLI_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0