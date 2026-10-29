#!/usr/bin/env bash
# Approval (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_approval

# Create a cost center.
create_out="$(run_cobol "APR_CREATE|APR-W17-1|RequesterA|LEVEL1|||admin@test.com")"
assert_match "APR_CREATE ok" "$create_out" "SUCCESS\|APR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM approval WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "APR_CREATE|APR-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "APR_GET ok" "$(run_cobol "APR_GET|${id}|||||admin@test.com")" "SUCCESS\|APR_GET\|${id}\|APR-W17-1"
assert_match "APR_LIST ok" "$(run_cobol "APR_LIST|||50|0||admin@test.com")" "APR-W17-1"

# Allocate.
assert_match "APR_CALC ok" "$(run_cobol "APR_CALC|${id}|||||admin@test.com")" "SUCCESS\|APR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM approval WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "APR_DELETE ok" "$(run_cobol "APR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|APR_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM approval WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "APR_SUMMARY ok" "$(run_cobol "APR_SUMMARY||||||admin@test.com")" "SUCCESS\|APR_SUMMARY"
assert_match "APR_AUDIT ok" "$(run_cobol "APR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|APR_AUDIT"
assert_match "APR_VALIDATE ok" "$(run_cobol "APR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|APR_VALID"
assert_match "non-admin refused" "$(run_cobol "APR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0