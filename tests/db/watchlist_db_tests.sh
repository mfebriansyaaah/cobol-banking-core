#!/usr/bin/env bash
# Watchlist (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_watchlist

# Create a cost center.
create_out="$(run_cobol "WTC_CREATE|WTC-W8-1|EntityA|PEP|||admin@test.com")"
assert_match "WTC_CREATE ok" "$create_out" "SUCCESS\|WTC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM watchlist WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "WTC_CREATE|WTC-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "WTC_GET ok" "$(run_cobol "WTC_GET|${id}|||||admin@test.com")" "SUCCESS\|WTC_GET\|${id}\|WTC-W8-1"
assert_match "WTC_LIST ok" "$(run_cobol "WTC_LIST|||50|0||admin@test.com")" "WTC-W8-1"

# Allocate.
assert_match "WTC_CALC ok" "$(run_cobol "WTC_CALC|${id}|||||admin@test.com")" "SUCCESS\|WTC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM watchlist WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "WTC_DELETE ok" "$(run_cobol "WTC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|WTC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM watchlist WHERE id=${id};")" "^WATCHED$"

# Summary and audit.
assert_match "WTC_SUMMARY ok" "$(run_cobol "WTC_SUMMARY||||||admin@test.com")" "SUCCESS\|WTC_SUMMARY"
assert_match "WTC_AUDIT ok" "$(run_cobol "WTC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|WTC_AUDIT"
assert_match "WTC_VALIDATE ok" "$(run_cobol "WTC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|WTC_VALID"
assert_match "non-admin refused" "$(run_cobol "WTC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0