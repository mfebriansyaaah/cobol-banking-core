#!/usr/bin/env bash
# Benchmark (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_benchmark

# Create a cost center.
create_out="$(run_cobol "BNM_CREATE|BNM-W14-1|BenchA|INDEX|||admin@test.com")"
assert_match "BNM_CREATE ok" "$create_out" "SUCCESS\|BNM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM benchmark WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BNM_CREATE|BNM-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BNM_GET ok" "$(run_cobol "BNM_GET|${id}|||||admin@test.com")" "SUCCESS\|BNM_GET\|${id}\|BNM-W14-1"
assert_match "BNM_LIST ok" "$(run_cobol "BNM_LIST|||50|0||admin@test.com")" "BNM-W14-1"

# Allocate.
assert_match "BNM_CALC ok" "$(run_cobol "BNM_CALC|${id}|||||admin@test.com")" "SUCCESS\|BNM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM benchmark WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "BNM_DELETE ok" "$(run_cobol "BNM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|BNM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM benchmark WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "BNM_SUMMARY ok" "$(run_cobol "BNM_SUMMARY||||||admin@test.com")" "SUCCESS\|BNM_SUMMARY"
assert_match "BNM_AUDIT ok" "$(run_cobol "BNM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BNM_AUDIT"
assert_match "BNM_VALIDATE ok" "$(run_cobol "BNM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BNM_VALID"
assert_match "non-admin refused" "$(run_cobol "BNM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0