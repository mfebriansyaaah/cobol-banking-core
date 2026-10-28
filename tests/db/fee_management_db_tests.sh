#!/usr/bin/env bash
# Fee management (Wave5) end-to-end DB tests via the COBOL binary.
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
db_reset_fee_management

# Create a cost center.
create_out="$(run_cobol "FMM_CREATE|FMM-W5-1|FeeA|ADMIN|||admin@test.com")"
assert_match "FMM_CREATE ok" "$create_out" "SUCCESS\|FMM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM fee_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FMM_CREATE|FMM-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FMM_GET ok" "$(run_cobol "FMM_GET|${id}|||||admin@test.com")" "SUCCESS\|FMM_GET\|${id}\|FMM-W5-1"
assert_match "FMM_LIST ok" "$(run_cobol "FMM_LIST|||50|0||admin@test.com")" "FMM-W5-1"

# Allocate.
assert_match "FMM_CALC ok" "$(run_cobol "FMM_CALC|${id}|||||admin@test.com")" "SUCCESS\|FMM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT collected_fee FROM fee_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FMM_DELETE ok" "$(run_cobol "FMM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FMM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM fee_management WHERE id=${id};")" "^INACTIVE$"

# Summary and audit.
assert_match "FMM_SUMMARY ok" "$(run_cobol "FMM_SUMMARY||||||admin@test.com")" "SUCCESS\|FMM_SUMMARY"
assert_match "FMM_AUDIT ok" "$(run_cobol "FMM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FMM_AUDIT"
assert_match "FMM_VALIDATE ok" "$(run_cobol "FMM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FMM_VALID"
assert_match "non-admin refused" "$(run_cobol "FMM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0