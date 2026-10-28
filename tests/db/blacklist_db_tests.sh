#!/usr/bin/env bash
# Blacklist (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_blacklist

# Create a cost center.
create_out="$(run_cobol "BLK_CREATE|BLK-W8-1|EntityA|SANCTIONS|||admin@test.com")"
assert_match "BLK_CREATE ok" "$create_out" "SUCCESS\|BLK_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM blacklist WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BLK_CREATE|BLK-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BLK_GET ok" "$(run_cobol "BLK_GET|${id}|||||admin@test.com")" "SUCCESS\|BLK_GET\|${id}\|BLK-W8-1"
assert_match "BLK_LIST ok" "$(run_cobol "BLK_LIST|||50|0||admin@test.com")" "BLK-W8-1"

# Allocate.
assert_match "BLK_CALC ok" "$(run_cobol "BLK_CALC|${id}|||||admin@test.com")" "SUCCESS\|BLK_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM blacklist WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "BLK_DELETE ok" "$(run_cobol "BLK_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|BLK_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM blacklist WHERE id=${id};")" "^BLACKLISTED$"

# Summary and audit.
assert_match "BLK_SUMMARY ok" "$(run_cobol "BLK_SUMMARY||||||admin@test.com")" "SUCCESS\|BLK_SUMMARY"
assert_match "BLK_AUDIT ok" "$(run_cobol "BLK_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BLK_AUDIT"
assert_match "BLK_VALIDATE ok" "$(run_cobol "BLK_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BLK_VALID"
assert_match "non-admin refused" "$(run_cobol "BLK_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0