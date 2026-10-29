#!/usr/bin/env bash
# Procedure review (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_procedure_review

# Create a cost center.
create_out="$(run_cobol "PRR_CREATE|PRR-W17-1|ProcedureA|SOP|||admin@test.com")"
assert_match "PRR_CREATE ok" "$create_out" "SUCCESS\|PRR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM procedure_review WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PRR_CREATE|PRR-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PRR_GET ok" "$(run_cobol "PRR_GET|${id}|||||admin@test.com")" "SUCCESS\|PRR_GET\|${id}\|PRR-W17-1"
assert_match "PRR_LIST ok" "$(run_cobol "PRR_LIST|||50|0||admin@test.com")" "PRR-W17-1"

# Allocate.
assert_match "PRR_CALC ok" "$(run_cobol "PRR_CALC|${id}|||||admin@test.com")" "SUCCESS\|PRR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM procedure_review WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PRR_DELETE ok" "$(run_cobol "PRR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PRR_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM procedure_review WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PRR_SUMMARY ok" "$(run_cobol "PRR_SUMMARY||||||admin@test.com")" "SUCCESS\|PRR_SUMMARY"
assert_match "PRR_AUDIT ok" "$(run_cobol "PRR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PRR_AUDIT"
assert_match "PRR_VALIDATE ok" "$(run_cobol "PRR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PRR_VALID"
assert_match "non-admin refused" "$(run_cobol "PRR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0