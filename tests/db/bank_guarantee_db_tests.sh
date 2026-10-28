#!/usr/bin/env bash
# Bank guarantee (Wave4) end-to-end DB tests via the COBOL binary.
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
db_reset_bank_guarantee

# Create a cost center.
create_out="$(run_cobol "BKG_CREATE|BKG-W4-1|BeneficiaryA|BID|||admin@test.com")"
assert_match "BKG_CREATE ok" "$create_out" "SUCCESS\|BKG_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM bank_guarantee WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BKG_CREATE|BKG-W4-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BKG_GET ok" "$(run_cobol "BKG_GET|${id}|||||admin@test.com")" "SUCCESS\|BKG_GET\|${id}\|BKG-W4-1"
assert_match "BKG_LIST ok" "$(run_cobol "BKG_LIST|||50|0||admin@test.com")" "BKG-W4-1"

# Allocate.
assert_match "BKG_CALC ok" "$(run_cobol "BKG_CALC|${id}|||||admin@test.com")" "SUCCESS\|BKG_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT claimed_amount FROM bank_guarantee WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "BKG_DELETE ok" "$(run_cobol "BKG_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|BKG_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM bank_guarantee WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "BKG_SUMMARY ok" "$(run_cobol "BKG_SUMMARY||||||admin@test.com")" "SUCCESS\|BKG_SUMMARY"
assert_match "BKG_AUDIT ok" "$(run_cobol "BKG_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BKG_AUDIT"
assert_match "BKG_VALIDATE ok" "$(run_cobol "BKG_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BKG_VALID"
assert_match "non-admin refused" "$(run_cobol "BKG_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0