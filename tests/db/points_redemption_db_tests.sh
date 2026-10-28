#!/usr/bin/env bash
# Points redemption (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_points_redemption

# Create a cost center.
create_out="$(run_cobol "PTR_CREATE|PTR-W8-1|CustomerA|GIFT|||admin@test.com")"
assert_match "PTR_CREATE ok" "$create_out" "SUCCESS\|PTR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM points_redemption WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PTR_CREATE|PTR-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PTR_GET ok" "$(run_cobol "PTR_GET|${id}|||||admin@test.com")" "SUCCESS\|PTR_GET\|${id}\|PTR-W8-1"
assert_match "PTR_LIST ok" "$(run_cobol "PTR_LIST|||50|0||admin@test.com")" "PTR-W8-1"

# Allocate.
assert_match "PTR_CALC ok" "$(run_cobol "PTR_CALC|${id}|||||admin@test.com")" "SUCCESS\|PTR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM points_redemption WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PTR_DELETE ok" "$(run_cobol "PTR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PTR_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM points_redemption WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PTR_SUMMARY ok" "$(run_cobol "PTR_SUMMARY||||||admin@test.com")" "SUCCESS\|PTR_SUMMARY"
assert_match "PTR_AUDIT ok" "$(run_cobol "PTR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PTR_AUDIT"
assert_match "PTR_VALIDATE ok" "$(run_cobol "PTR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PTR_VALID"
assert_match "non-admin refused" "$(run_cobol "PTR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0