#!/usr/bin/env bash
# Health check (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_health_check

# Create a cost center.
create_out="$(run_cobol "HLC_CREATE|HLC-W11-1|ServiceA|LIVENESS|||admin@test.com")"
assert_match "HLC_CREATE ok" "$create_out" "SUCCESS\|HLC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM health_check WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "HLC_CREATE|HLC-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "HLC_GET ok" "$(run_cobol "HLC_GET|${id}|||||admin@test.com")" "SUCCESS\|HLC_GET\|${id}\|HLC-W11-1"
assert_match "HLC_LIST ok" "$(run_cobol "HLC_LIST|||50|0||admin@test.com")" "HLC-W11-1"

# Allocate.
assert_match "HLC_CALC ok" "$(run_cobol "HLC_CALC|${id}|||||admin@test.com")" "SUCCESS\|HLC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM health_check WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "HLC_DELETE ok" "$(run_cobol "HLC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|HLC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM health_check WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "HLC_SUMMARY ok" "$(run_cobol "HLC_SUMMARY||||||admin@test.com")" "SUCCESS\|HLC_SUMMARY"
assert_match "HLC_AUDIT ok" "$(run_cobol "HLC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|HLC_AUDIT"
assert_match "HLC_VALIDATE ok" "$(run_cobol "HLC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|HLC_VALID"
assert_match "non-admin refused" "$(run_cobol "HLC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0