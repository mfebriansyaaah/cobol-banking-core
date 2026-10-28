#!/usr/bin/env bash
# Margin trading (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_margin_trading

# Create a cost center.
create_out="$(run_cobol "MGT_CREATE|MGT-W6-1|TraderA|LEVERAGE|||admin@test.com")"
assert_match "MGT_CREATE ok" "$create_out" "SUCCESS\|MGT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM margin_trading WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MGT_CREATE|MGT-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MGT_GET ok" "$(run_cobol "MGT_GET|${id}|||||admin@test.com")" "SUCCESS\|MGT_GET\|${id}\|MGT-W6-1"
assert_match "MGT_LIST ok" "$(run_cobol "MGT_LIST|||50|0||admin@test.com")" "MGT-W6-1"

# Allocate.
assert_match "MGT_CALC ok" "$(run_cobol "MGT_CALC|${id}|||||admin@test.com")" "SUCCESS\|MGT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM margin_trading WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MGT_DELETE ok" "$(run_cobol "MGT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MGT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM margin_trading WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MGT_SUMMARY ok" "$(run_cobol "MGT_SUMMARY||||||admin@test.com")" "SUCCESS\|MGT_SUMMARY"
assert_match "MGT_AUDIT ok" "$(run_cobol "MGT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MGT_AUDIT"
assert_match "MGT_VALIDATE ok" "$(run_cobol "MGT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MGT_VALID"
assert_match "non-admin refused" "$(run_cobol "MGT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0