#!/usr/bin/env bash
# Daily limit (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_daily_limit

# Create a cost center.
create_out="$(run_cobol "DLY_CREATE|DLY-W8-1|AccountA|WITHDRAWAL|||admin@test.com")"
assert_match "DLY_CREATE ok" "$create_out" "SUCCESS\|DLY_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM daily_limit WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DLY_CREATE|DLY-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DLY_GET ok" "$(run_cobol "DLY_GET|${id}|||||admin@test.com")" "SUCCESS\|DLY_GET\|${id}\|DLY-W8-1"
assert_match "DLY_LIST ok" "$(run_cobol "DLY_LIST|||50|0||admin@test.com")" "DLY-W8-1"

# Allocate.
assert_match "DLY_CALC ok" "$(run_cobol "DLY_CALC|${id}|||||admin@test.com")" "SUCCESS\|DLY_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM daily_limit WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DLY_DELETE ok" "$(run_cobol "DLY_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DLY_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM daily_limit WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "DLY_SUMMARY ok" "$(run_cobol "DLY_SUMMARY||||||admin@test.com")" "SUCCESS\|DLY_SUMMARY"
assert_match "DLY_AUDIT ok" "$(run_cobol "DLY_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DLY_AUDIT"
assert_match "DLY_VALIDATE ok" "$(run_cobol "DLY_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DLY_VALID"
assert_match "non-admin refused" "$(run_cobol "DLY_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0