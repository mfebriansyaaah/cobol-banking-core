#!/usr/bin/env bash
# Consolidation (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_consolidation_mgmt

# Create a cost center.
create_out="$(run_cobol "CONS_CREATE|CONS-W14-1|ConsolA|GROUP|||admin@test.com")"
assert_match "CONS_CREATE ok" "$create_out" "SUCCESS\|CONS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM consolidation_mgmt WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CONS_CREATE|CONS-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CONS_GET ok" "$(run_cobol "CONS_GET|${id}|||||admin@test.com")" "SUCCESS\|CONS_GET\|${id}\|CONS-W14-1"
assert_match "CONS_LIST ok" "$(run_cobol "CONS_LIST|||50|0||admin@test.com")" "CONS-W14-1"

# Allocate.
assert_match "CONS_CALC ok" "$(run_cobol "CONS_CALC|${id}|||||admin@test.com")" "SUCCESS\|CONS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM consolidation_mgmt WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CONS_DELETE ok" "$(run_cobol "CONS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CONS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM consolidation_mgmt WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CONS_SUMMARY ok" "$(run_cobol "CONS_SUMMARY||||||admin@test.com")" "SUCCESS\|CONS_SUMMARY"
assert_match "CONS_AUDIT ok" "$(run_cobol "CONS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CONS_AUDIT"
assert_match "CONS_VALIDATE ok" "$(run_cobol "CONS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CONS_VALID"
assert_match "non-admin refused" "$(run_cobol "CONS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0