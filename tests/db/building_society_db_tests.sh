#!/usr/bin/env bash
# Building society (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_building_society

# Create a cost center.
create_out="$(run_cobol "BLS_CREATE|BLS-W20-1|SocietyA|MUTUAL|||admin@test.com")"
assert_match "BLS_CREATE ok" "$create_out" "SUCCESS\|BLS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM building_society WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BLS_CREATE|BLS-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BLS_GET ok" "$(run_cobol "BLS_GET|${id}|||||admin@test.com")" "SUCCESS\|BLS_GET\|${id}\|BLS-W20-1"
assert_match "BLS_LIST ok" "$(run_cobol "BLS_LIST|||50|0||admin@test.com")" "BLS-W20-1"

# Allocate.
assert_match "BLS_CALC ok" "$(run_cobol "BLS_CALC|${id}|||||admin@test.com")" "SUCCESS\|BLS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM building_society WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "BLS_DELETE ok" "$(run_cobol "BLS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|BLS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM building_society WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "BLS_SUMMARY ok" "$(run_cobol "BLS_SUMMARY||||||admin@test.com")" "SUCCESS\|BLS_SUMMARY"
assert_match "BLS_AUDIT ok" "$(run_cobol "BLS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BLS_AUDIT"
assert_match "BLS_VALIDATE ok" "$(run_cobol "BLS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BLS_VALID"
assert_match "non-admin refused" "$(run_cobol "BLS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0