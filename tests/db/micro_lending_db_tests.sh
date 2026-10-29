#!/usr/bin/env bash
# Micro lending (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_micro_lending

# Create a cost center.
create_out="$(run_cobol "MCL_CREATE|MCL-W20-1|MicroA|GROUP|||admin@test.com")"
assert_match "MCL_CREATE ok" "$create_out" "SUCCESS\|MCL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM micro_lending WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MCL_CREATE|MCL-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MCL_GET ok" "$(run_cobol "MCL_GET|${id}|||||admin@test.com")" "SUCCESS\|MCL_GET\|${id}\|MCL-W20-1"
assert_match "MCL_LIST ok" "$(run_cobol "MCL_LIST|||50|0||admin@test.com")" "MCL-W20-1"

# Allocate.
assert_match "MCL_CALC ok" "$(run_cobol "MCL_CALC|${id}|||||admin@test.com")" "SUCCESS\|MCL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM micro_lending WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MCL_DELETE ok" "$(run_cobol "MCL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MCL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM micro_lending WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MCL_SUMMARY ok" "$(run_cobol "MCL_SUMMARY||||||admin@test.com")" "SUCCESS\|MCL_SUMMARY"
assert_match "MCL_AUDIT ok" "$(run_cobol "MCL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MCL_AUDIT"
assert_match "MCL_VALIDATE ok" "$(run_cobol "MCL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MCL_VALID"
assert_match "non-admin refused" "$(run_cobol "MCL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0