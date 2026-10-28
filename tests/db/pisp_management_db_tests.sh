#!/usr/bin/env bash
# PISP management (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_pisp_management

# Create a cost center.
create_out="$(run_cobol "PIS_CREATE|PIS-W6-1|PISPA|PAYMENT|||admin@test.com")"
assert_match "PIS_CREATE ok" "$create_out" "SUCCESS\|PIS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM pisp_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PIS_CREATE|PIS-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PIS_GET ok" "$(run_cobol "PIS_GET|${id}|||||admin@test.com")" "SUCCESS\|PIS_GET\|${id}\|PIS-W6-1"
assert_match "PIS_LIST ok" "$(run_cobol "PIS_LIST|||50|0||admin@test.com")" "PIS-W6-1"

# Allocate.
assert_match "PIS_CALC ok" "$(run_cobol "PIS_CALC|${id}|||||admin@test.com")" "SUCCESS\|PIS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM pisp_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PIS_DELETE ok" "$(run_cobol "PIS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PIS_DELETE"
assert_match "inactive persisted" "$(db_query "SELECT status FROM pisp_management WHERE id=${id};")" "^INACTIVE$"

# Summary and audit.
assert_match "PIS_SUMMARY ok" "$(run_cobol "PIS_SUMMARY||||||admin@test.com")" "SUCCESS\|PIS_SUMMARY"
assert_match "PIS_AUDIT ok" "$(run_cobol "PIS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PIS_AUDIT"
assert_match "PIS_VALIDATE ok" "$(run_cobol "PIS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PIS_VALID"
assert_match "non-admin refused" "$(run_cobol "PIS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0