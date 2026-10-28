#!/usr/bin/env bash
# Loss reserve (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_loss_reserve

# Create a cost center.
create_out="$(run_cobol "LSR_CREATE|LSR-W7-1|ReserveA|CLAIM|||admin@test.com")"
assert_match "LSR_CREATE ok" "$create_out" "SUCCESS\|LSR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM loss_reserve WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "LSR_CREATE|LSR-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "LSR_GET ok" "$(run_cobol "LSR_GET|${id}|||||admin@test.com")" "SUCCESS\|LSR_GET\|${id}\|LSR-W7-1"
assert_match "LSR_LIST ok" "$(run_cobol "LSR_LIST|||50|0||admin@test.com")" "LSR-W7-1"

# Allocate.
assert_match "LSR_CALC ok" "$(run_cobol "LSR_CALC|${id}|||||admin@test.com")" "SUCCESS\|LSR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM loss_reserve WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "LSR_DELETE ok" "$(run_cobol "LSR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|LSR_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM loss_reserve WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "LSR_SUMMARY ok" "$(run_cobol "LSR_SUMMARY||||||admin@test.com")" "SUCCESS\|LSR_SUMMARY"
assert_match "LSR_AUDIT ok" "$(run_cobol "LSR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|LSR_AUDIT"
assert_match "LSR_VALIDATE ok" "$(run_cobol "LSR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|LSR_VALID"
assert_match "non-admin refused" "$(run_cobol "LSR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0