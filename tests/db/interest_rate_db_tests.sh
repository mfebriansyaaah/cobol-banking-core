#!/usr/bin/env bash
# Interest rate (Wave1) end-to-end DB tests via the COBOL binary.
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
db_reset_interest_rate

# Create a cost center.
create_out="$(run_cobol "IRT_CREATE|IRT-W1-1|Base Rate|FIXED|||admin@test.com")"
assert_match "IRT_CREATE ok" "$create_out" "SUCCESS\|IRT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM interest_rate WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "IRT_CREATE|IRT-W1-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "IRT_GET ok" "$(run_cobol "IRT_GET|${id}|||||admin@test.com")" "SUCCESS\|IRT_GET\|${id}\|IRT-W1-1"
assert_match "IRT_LIST ok" "$(run_cobol "IRT_LIST|||50|0||admin@test.com")" "IRT-W1-1"

# Allocate.
assert_match "IRT_CALC ok" "$(run_cobol "IRT_CALC|${id}|||||admin@test.com")" "SUCCESS\|IRT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT applied_count FROM interest_rate WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "IRT_DELETE ok" "$(run_cobol "IRT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|IRT_DELETE"
assert_match "retired persisted" "$(db_query "SELECT status FROM interest_rate WHERE id=${id};")" "^RETIRED$"

# Summary and audit.
assert_match "IRT_SUMMARY ok" "$(run_cobol "IRT_SUMMARY||||||admin@test.com")" "SUCCESS\|IRT_SUMMARY"
assert_match "IRT_AUDIT ok" "$(run_cobol "IRT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|IRT_AUDIT"
assert_match "IRT_VALIDATE ok" "$(run_cobol "IRT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|IRT_VALID"
assert_match "non-admin refused" "$(run_cobol "IRT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0