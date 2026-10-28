#!/usr/bin/env bash
# Load balancer (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_load_balancer

# Create a cost center.
create_out="$(run_cobol "LDB_CREATE|LDB-W11-1|LBA|ROUND_ROBIN|||admin@test.com")"
assert_match "LDB_CREATE ok" "$create_out" "SUCCESS\|LDB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM load_balancer WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "LDB_CREATE|LDB-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "LDB_GET ok" "$(run_cobol "LDB_GET|${id}|||||admin@test.com")" "SUCCESS\|LDB_GET\|${id}\|LDB-W11-1"
assert_match "LDB_LIST ok" "$(run_cobol "LDB_LIST|||50|0||admin@test.com")" "LDB-W11-1"

# Allocate.
assert_match "LDB_CALC ok" "$(run_cobol "LDB_CALC|${id}|||||admin@test.com")" "SUCCESS\|LDB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM load_balancer WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "LDB_DELETE ok" "$(run_cobol "LDB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|LDB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM load_balancer WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "LDB_SUMMARY ok" "$(run_cobol "LDB_SUMMARY||||||admin@test.com")" "SUCCESS\|LDB_SUMMARY"
assert_match "LDB_AUDIT ok" "$(run_cobol "LDB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|LDB_AUDIT"
assert_match "LDB_VALIDATE ok" "$(run_cobol "LDB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|LDB_VALID"
assert_match "non-admin refused" "$(run_cobol "LDB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0