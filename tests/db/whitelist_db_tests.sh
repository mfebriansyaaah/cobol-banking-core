#!/usr/bin/env bash
# Whitelist (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_whitelist

# Create a cost center.
create_out="$(run_cobol "WHT_CREATE|WHT-W8-1|EntityA|TRUSTED|||admin@test.com")"
assert_match "WHT_CREATE ok" "$create_out" "SUCCESS\|WHT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM whitelist WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "WHT_CREATE|WHT-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "WHT_GET ok" "$(run_cobol "WHT_GET|${id}|||||admin@test.com")" "SUCCESS\|WHT_GET\|${id}\|WHT-W8-1"
assert_match "WHT_LIST ok" "$(run_cobol "WHT_LIST|||50|0||admin@test.com")" "WHT-W8-1"

# Allocate.
assert_match "WHT_CALC ok" "$(run_cobol "WHT_CALC|${id}|||||admin@test.com")" "SUCCESS\|WHT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM whitelist WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "WHT_DELETE ok" "$(run_cobol "WHT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|WHT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM whitelist WHERE id=${id};")" "^WHITELISTED$"

# Summary and audit.
assert_match "WHT_SUMMARY ok" "$(run_cobol "WHT_SUMMARY||||||admin@test.com")" "SUCCESS\|WHT_SUMMARY"
assert_match "WHT_AUDIT ok" "$(run_cobol "WHT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|WHT_AUDIT"
assert_match "WHT_VALIDATE ok" "$(run_cobol "WHT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|WHT_VALID"
assert_match "non-admin refused" "$(run_cobol "WHT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0