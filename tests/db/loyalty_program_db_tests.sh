#!/usr/bin/env bash
# Loyalty program (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_loyalty_program

# Create a cost center.
create_out="$(run_cobol "LYP_CREATE|LYP-W8-1|ProgramA|POINTS|||admin@test.com")"
assert_match "LYP_CREATE ok" "$create_out" "SUCCESS\|LYP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM loyalty_program WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "LYP_CREATE|LYP-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "LYP_GET ok" "$(run_cobol "LYP_GET|${id}|||||admin@test.com")" "SUCCESS\|LYP_GET\|${id}\|LYP-W8-1"
assert_match "LYP_LIST ok" "$(run_cobol "LYP_LIST|||50|0||admin@test.com")" "LYP-W8-1"

# Allocate.
assert_match "LYP_CALC ok" "$(run_cobol "LYP_CALC|${id}|||||admin@test.com")" "SUCCESS\|LYP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM loyalty_program WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "LYP_DELETE ok" "$(run_cobol "LYP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|LYP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM loyalty_program WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "LYP_SUMMARY ok" "$(run_cobol "LYP_SUMMARY||||||admin@test.com")" "SUCCESS\|LYP_SUMMARY"
assert_match "LYP_AUDIT ok" "$(run_cobol "LYP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|LYP_AUDIT"
assert_match "LYP_VALIDATE ok" "$(run_cobol "LYP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|LYP_VALID"
assert_match "non-admin refused" "$(run_cobol "LYP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0