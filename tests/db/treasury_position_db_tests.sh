#!/usr/bin/env bash
# treasury_position (T-020) end-to-end DB tests via the COBOL binary.
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
db_reset_treasury_position

# Open a USD 50000 position as of 2026-02-01.
open_out="$(run_cobol "TRP_OPEN|USD|50000.00|2026-02-01|||admin@test.com")"
assert_match "TRP_OPEN ok" "$open_out" "SUCCESS\|TRP_OPENED"
pos_id="$(db_query "SELECT id FROM treasury_position WHERE currency='USD' AND as_of_date='2026-02-01' ORDER BY id DESC LIMIT 1;")"
assert_match "position id present" "$pos_id" "^[0-9]+$"
assert_match "position open" "$(db_query "SELECT status FROM treasury_position WHERE id=${pos_id};")" "^OPEN$"
assert_match "open audited" "$(db_query "SELECT COUNT(*) FROM treasury_audit WHERE action='OPEN';")" "^1$"

# List carries the open position; summary aggregates it.
list_out="$(run_cobol "TRP_LIST||50|0|||admin@test.com")"
assert_match "TRP_LIST ok" "$list_out" "SUCCESS\|TRP_POSITIONS\|"
assert_match "list carries the position" "$list_out" "USD"
assert_match "TRP_SUMMARY ok" "$(run_cobol "TRP_SUMMARY||||||admin@test.com")" "SUCCESS\|TRP_SUMMARY\|1\|1\|0\|50000.0000"

# Close; closing twice is refused.
assert_match "TRP_CLOSE ok" "$(run_cobol "TRP_CLOSE|${pos_id}|||||admin@test.com")" "SUCCESS\|TRP_CLOSED"
assert_match "position closed" "$(db_query "SELECT status FROM treasury_position WHERE id=${pos_id};")" "^CLOSED$"
assert_match "close closed refused" "$(run_cobol "TRP_CLOSE|${pos_id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "close missing id" "$(run_cobol "TRP_CLOSE||||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "non-admin refused" "$(run_cobol "TRP_LIST||50|0|||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
