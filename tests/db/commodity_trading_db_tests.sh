#!/usr/bin/env bash
# Commodity trading (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_commodity_trading

# Create a cost center.
create_out="$(run_cobol "CMD_CREATE|CMD-W6-1|CommodityA|GOLD|||admin@test.com")"
assert_match "CMD_CREATE ok" "$create_out" "SUCCESS\|CMD_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM commodity_trading WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CMD_CREATE|CMD-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CMD_GET ok" "$(run_cobol "CMD_GET|${id}|||||admin@test.com")" "SUCCESS\|CMD_GET\|${id}\|CMD-W6-1"
assert_match "CMD_LIST ok" "$(run_cobol "CMD_LIST|||50|0||admin@test.com")" "CMD-W6-1"

# Allocate.
assert_match "CMD_CALC ok" "$(run_cobol "CMD_CALC|${id}|||||admin@test.com")" "SUCCESS\|CMD_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM commodity_trading WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CMD_DELETE ok" "$(run_cobol "CMD_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CMD_DELETE"
assert_match "delivered persisted" "$(db_query "SELECT status FROM commodity_trading WHERE id=${id};")" "^DELIVERED$"

# Summary and audit.
assert_match "CMD_SUMMARY ok" "$(run_cobol "CMD_SUMMARY||||||admin@test.com")" "SUCCESS\|CMD_SUMMARY"
assert_match "CMD_AUDIT ok" "$(run_cobol "CMD_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CMD_AUDIT"
assert_match "CMD_VALIDATE ok" "$(run_cobol "CMD_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CMD_VALID"
assert_match "non-admin refused" "$(run_cobol "CMD_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0