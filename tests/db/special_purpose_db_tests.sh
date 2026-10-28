#!/usr/bin/env bash
# Special purpose (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_special_purpose

# Create a cost center.
create_out="$(run_cobol "SPE_CREATE|SPE-W12-1|SpeA|VEHICLE|||admin@test.com")"
assert_match "SPE_CREATE ok" "$create_out" "SUCCESS\|SPE_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM special_purpose WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SPE_CREATE|SPE-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SPE_GET ok" "$(run_cobol "SPE_GET|${id}|||||admin@test.com")" "SUCCESS\|SPE_GET\|${id}\|SPE-W12-1"
assert_match "SPE_LIST ok" "$(run_cobol "SPE_LIST|||50|0||admin@test.com")" "SPE-W12-1"

# Allocate.
assert_match "SPE_CALC ok" "$(run_cobol "SPE_CALC|${id}|||||admin@test.com")" "SUCCESS\|SPE_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM special_purpose WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SPE_DELETE ok" "$(run_cobol "SPE_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SPE_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM special_purpose WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SPE_SUMMARY ok" "$(run_cobol "SPE_SUMMARY||||||admin@test.com")" "SUCCESS\|SPE_SUMMARY"
assert_match "SPE_AUDIT ok" "$(run_cobol "SPE_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SPE_AUDIT"
assert_match "SPE_VALIDATE ok" "$(run_cobol "SPE_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SPE_VALID"
assert_match "non-admin refused" "$(run_cobol "SPE_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0