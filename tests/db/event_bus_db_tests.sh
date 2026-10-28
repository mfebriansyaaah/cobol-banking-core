#!/usr/bin/env bash
# Event bus (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_event_bus

# Create a cost center.
create_out="$(run_cobol "EVB_CREATE|EVB-W11-1|BusA|KAFKA|||admin@test.com")"
assert_match "EVB_CREATE ok" "$create_out" "SUCCESS\|EVB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM event_bus WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "EVB_CREATE|EVB-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "EVB_GET ok" "$(run_cobol "EVB_GET|${id}|||||admin@test.com")" "SUCCESS\|EVB_GET\|${id}\|EVB-W11-1"
assert_match "EVB_LIST ok" "$(run_cobol "EVB_LIST|||50|0||admin@test.com")" "EVB-W11-1"

# Allocate.
assert_match "EVB_CALC ok" "$(run_cobol "EVB_CALC|${id}|||||admin@test.com")" "SUCCESS\|EVB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM event_bus WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "EVB_DELETE ok" "$(run_cobol "EVB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|EVB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM event_bus WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "EVB_SUMMARY ok" "$(run_cobol "EVB_SUMMARY||||||admin@test.com")" "SUCCESS\|EVB_SUMMARY"
assert_match "EVB_AUDIT ok" "$(run_cobol "EVB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|EVB_AUDIT"
assert_match "EVB_VALIDATE ok" "$(run_cobol "EVB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|EVB_VALID"
assert_match "non-admin refused" "$(run_cobol "EVB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0