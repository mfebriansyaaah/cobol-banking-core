#!/usr/bin/env bash
# Deactivation item (Wave15) end-to-end DB tests via the COBOL binary.
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
db_reset_deactivation_item

# Create a cost center.
create_out="$(run_cobol "DEACT_CREATE|DEACT-W15-1|AccountA|SERVICE|||admin@test.com")"
assert_match "DEACT_CREATE ok" "$create_out" "SUCCESS\|DEACT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM deactivation_item WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DEACT_CREATE|DEACT-W15-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DEACT_GET ok" "$(run_cobol "DEACT_GET|${id}|||||admin@test.com")" "SUCCESS\|DEACT_GET\|${id}\|DEACT-W15-1"
assert_match "DEACT_LIST ok" "$(run_cobol "DEACT_LIST|||50|0||admin@test.com")" "DEACT-W15-1"

# Allocate.
assert_match "DEACT_CALC ok" "$(run_cobol "DEACT_CALC|${id}|||||admin@test.com")" "SUCCESS\|DEACT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM deactivation_item WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DEACT_DELETE ok" "$(run_cobol "DEACT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DEACT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM deactivation_item WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "DEACT_SUMMARY ok" "$(run_cobol "DEACT_SUMMARY||||||admin@test.com")" "SUCCESS\|DEACT_SUMMARY"
assert_match "DEACT_AUDIT ok" "$(run_cobol "DEACT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DEACT_AUDIT"
assert_match "DEACT_VALIDATE ok" "$(run_cobol "DEACT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DEACT_VALID"
assert_match "non-admin refused" "$(run_cobol "DEACT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0