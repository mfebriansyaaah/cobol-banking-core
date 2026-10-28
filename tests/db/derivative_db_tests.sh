#!/usr/bin/env bash
# Derivative (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_derivative

# Create a cost center.
create_out="$(run_cobol "DRV_CREATE|DRV-W12-1|DerivA|FORWARD|||admin@test.com")"
assert_match "DRV_CREATE ok" "$create_out" "SUCCESS\|DRV_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM derivative WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DRV_CREATE|DRV-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DRV_GET ok" "$(run_cobol "DRV_GET|${id}|||||admin@test.com")" "SUCCESS\|DRV_GET\|${id}\|DRV-W12-1"
assert_match "DRV_LIST ok" "$(run_cobol "DRV_LIST|||50|0||admin@test.com")" "DRV-W12-1"

# Allocate.
assert_match "DRV_CALC ok" "$(run_cobol "DRV_CALC|${id}|||||admin@test.com")" "SUCCESS\|DRV_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM derivative WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DRV_DELETE ok" "$(run_cobol "DRV_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DRV_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM derivative WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "DRV_SUMMARY ok" "$(run_cobol "DRV_SUMMARY||||||admin@test.com")" "SUCCESS\|DRV_SUMMARY"
assert_match "DRV_AUDIT ok" "$(run_cobol "DRV_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DRV_AUDIT"
assert_match "DRV_VALIDATE ok" "$(run_cobol "DRV_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DRV_VALID"
assert_match "non-admin refused" "$(run_cobol "DRV_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0